#include "lilc_picoc_runner.h"

#include "../picoc.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <unistd.h>

#define LILC_PICOC_STACK_SIZE (128000 * 4)
#define LILC_OUTPUT_LIMIT (128 * 1024)
#define LILC_STEP_LIMIT 200000

static pthread_mutex_t RunnerMutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t StdinMutex = PTHREAD_MUTEX_INITIALIZER;
static char *OutputBuffer = NULL;
static size_t OutputLength = 0;
static size_t OutputCapacity = 0;
static unsigned int StepCount = 0;
static int ExecutionStopped = 0;
static int StoppedByUser = 0;
static int StdinReadFD = -1;
static int StdinWriteFD = -1;
static FILE *StdinFile = NULL;
static lilc_output_hook PendingOutputHook = NULL;
static void *PendingOutputHookContext = NULL;
static lilc_output_hook OutputHook = NULL;
static void *OutputHookContext = NULL;
static lilc_input_wait_hook PendingInputWaitHook = NULL;
static void *PendingInputWaitHookContext = NULL;
static lilc_input_wait_hook InputWaitHook = NULL;
static void *InputWaitHookContext = NULL;

static char *CopyString(const char *text)
{
    size_t length = strlen(text);
    char *copy = malloc(length + 1);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, text, length + 1);
    return copy;
}

static void CloseStdinWriteLocked(void)
{
    if (StdinWriteFD >= 0) {
        close(StdinWriteFD);
        StdinWriteFD = -1;
    }
}

static void DestroyStdinPipe(void)
{
    pthread_mutex_lock(&StdinMutex);
    CloseStdinWriteLocked();
    if (StdinFile != NULL) {
        fclose(StdinFile);
        StdinFile = NULL;
        StdinReadFD = -1;
    } else if (StdinReadFD >= 0) {
        close(StdinReadFD);
        StdinReadFD = -1;
    }
    pthread_mutex_unlock(&StdinMutex);
}

static int OpenStdinPipe(void)
{
    int fds[2];

    DestroyStdinPipe();
    if (pipe(fds) != 0) {
        return -1;
    }

    pthread_mutex_lock(&StdinMutex);
    StdinReadFD = fds[0];
    StdinWriteFD = fds[1];
    StdinFile = fdopen(StdinReadFD, "r");
    if (StdinFile == NULL) {
        close(StdinReadFD);
        close(StdinWriteFD);
        StdinReadFD = -1;
        StdinWriteFD = -1;
        pthread_mutex_unlock(&StdinMutex);
        return -1;
    }
    setvbuf(StdinFile, NULL, _IONBF, 0);
    pthread_mutex_unlock(&StdinMutex);
    return 0;
}

FILE *LilCStdinFile(void)
{
    FILE *file;

    pthread_mutex_lock(&StdinMutex);
    file = StdinFile;
    pthread_mutex_unlock(&StdinMutex);
    return file != NULL ? file : stdin;
}

void lilc_picoc_set_output_hook(lilc_output_hook hook, void *context)
{
    PendingOutputHook = hook;
    PendingOutputHookContext = context;
}

void lilc_picoc_set_input_wait_hook(lilc_input_wait_hook hook, void *context)
{
    PendingInputWaitHook = hook;
    PendingInputWaitHookContext = context;
}

/* Blocks until the stdin pipe has bytes ready, the pipe closes, or the program
   is asked to stop. If it has to wait for the user it fires the input-wait hook
   so the UI can reflect that the program is paused for input. Returns 1 when
   data is ready to read, 0 when input is closed or the run is stopping. */
static int WaitForStdinData(int fd)
{
    int notifiedWaiting = 0;
    int result = 0;

    for (;;) {
        fd_set readSet;
        struct timeval timeout;
        int ready;

        if (StoppedByUser || ExecutionStopped) {
            break;
        }

        FD_ZERO(&readSet);
        FD_SET(fd, &readSet);
        timeout.tv_sec = 0;
        timeout.tv_usec = 40000; /* 40ms poll so we can react to stop/close */

        ready = select(fd + 1, &readSet, NULL, NULL, &timeout);
        if (ready > 0 && FD_ISSET(fd, &readSet)) {
            result = 1;
            break;
        }
        if (ready < 0) {
            break;
        }

        /* Nothing available yet: tell the UI we're waiting on the user. */
        if (!notifiedWaiting && InputWaitHook != NULL) {
            notifiedWaiting = 1;
            InputWaitHook(1, InputWaitHookContext);
        }
    }

    if (notifiedWaiting && InputWaitHook != NULL) {
        InputWaitHook(0, InputWaitHookContext);
    }
    return result;
}

void LilCWaitForInput(void)
{
    int fd;

    pthread_mutex_lock(&StdinMutex);
    fd = StdinReadFD;
    pthread_mutex_unlock(&StdinMutex);

    if (fd >= 0) {
        WaitForStdinData(fd);
    }
}

char *LilCReadLine(char *buf, int max_len)
{
    FILE *file;
    int fd;

    if (buf == NULL || max_len <= 1) {
        return NULL;
    }

    pthread_mutex_lock(&StdinMutex);
    file = StdinFile;
    fd = StdinReadFD;
    pthread_mutex_unlock(&StdinMutex);

    if (file == NULL || fd < 0) {
        return fgets(buf, max_len, file != NULL ? file : stdin);
    }
    if (!WaitForStdinData(fd)) {
        /* Give fgets a chance to drain anything already buffered / EOF. */
    }
    return fgets(buf, max_len, file);
}

int LilCReadChar(void)
{
    FILE *file;
    int fd;

    pthread_mutex_lock(&StdinMutex);
    file = StdinFile;
    fd = StdinReadFD;
    pthread_mutex_unlock(&StdinMutex);

    if (file == NULL || fd < 0) {
        return fgetc(file != NULL ? file : stdin);
    }
    WaitForStdinData(fd);
    return fgetc(file);
}

int lilc_picoc_feed_stdin(const char *bytes, int length)
{
    ssize_t written;

    if (bytes == NULL || length <= 0) {
        return -1;
    }

    pthread_mutex_lock(&StdinMutex);
    if (StdinWriteFD < 0) {
        pthread_mutex_unlock(&StdinMutex);
        return -1;
    }
    written = write(StdinWriteFD, bytes, (size_t)length);
    pthread_mutex_unlock(&StdinMutex);
    return written == (ssize_t)length ? 0 : -1;
}

void lilc_picoc_close_stdin(void)
{
    pthread_mutex_lock(&StdinMutex);
    CloseStdinWriteLocked();
    pthread_mutex_unlock(&StdinMutex);
}

void lilc_picoc_request_stop(void)
{
    ExecutionStopped = 1;
    StoppedByUser = 1;
    lilc_picoc_close_stdin();
}

static void OutputBegin(void)
{
    free(OutputBuffer);
    OutputLength = 0;
    OutputCapacity = 1024;
    StepCount = 0;
    ExecutionStopped = 0;
    StoppedByUser = 0;
    OutputBuffer = malloc(OutputCapacity);
    if (OutputBuffer != NULL) {
        OutputBuffer[0] = '\0';
    }
}

int LilCShouldStopExecution(void)
{
    StepCount++;
    if (StoppedByUser) {
        ExecutionStopped = 1;
        return 1;
    }
    if (StepCount > LILC_STEP_LIMIT) {
        ExecutionStopped = 1;
        return 1;
    }
    return 0;
}

void LilCOutputAppend(const char *Bytes, int Length)
{
    size_t incomingLength;
    size_t nextLength;
    size_t nextCapacity;
    char *nextBuffer;

    if (Bytes == NULL || Length <= 0 || OutputBuffer == NULL || OutputLength >= LILC_OUTPUT_LIMIT) {
        return;
    }

    incomingLength = (size_t)Length;
    if (OutputLength + incomingLength > LILC_OUTPUT_LIMIT) {
        incomingLength = LILC_OUTPUT_LIMIT - OutputLength;
    }
    nextLength = OutputLength + incomingLength;

    if (nextLength + 1 > OutputCapacity) {
        nextCapacity = OutputCapacity;
        while (nextCapacity < nextLength + 1) {
            nextCapacity *= 2;
        }
        if (nextCapacity > LILC_OUTPUT_LIMIT + 1) {
            nextCapacity = LILC_OUTPUT_LIMIT + 1;
        }
        nextBuffer = realloc(OutputBuffer, nextCapacity);
        if (nextBuffer == NULL) {
            return;
        }
        OutputBuffer = nextBuffer;
        OutputCapacity = nextCapacity;
    }

    memcpy(OutputBuffer + OutputLength, Bytes, incomingLength);
    OutputLength = nextLength;
    OutputBuffer[OutputLength] = '\0';

    if (OutputHook != NULL && incomingLength > 0) {
        OutputHook(OutputBuffer + OutputLength - incomingLength, (int)incomingLength, OutputHookContext);
    }
}

static char *OutputFinish(void)
{
    char *result;

    if (OutputBuffer == NULL) {
        return CopyString("lilC could not capture program output.\n");
    }
    if (ExecutionStopped && !StoppedByUser) {
        free(OutputBuffer);
        OutputBuffer = NULL;
        OutputLength = 0;
        OutputCapacity = 0;
        return CopyString("program stopped: too many steps\n");
    }
    if (ExecutionStopped && StoppedByUser) {
        const char *message = "\nprogram stopped.\n";
        LilCOutputAppend(message, (int)strlen(message));
    }
    if (OutputLength == 0) {
        free(OutputBuffer);
        OutputBuffer = NULL;
        OutputCapacity = 0;
        return CopyString("Program finished.\n");
    }

    result = OutputBuffer;
    OutputBuffer = NULL;
    OutputLength = 0;
    OutputCapacity = 0;
    return result;
}

static char *RunWithCapture(
    const char *source,
    const char *stdinText,
    int keepStdinOpen,
    const char *mainName,
    const char *const *extraNames,
    int extraCount,
    const char *includeRoot)
{
    Picoc pc;
    char *output;
    const char *parseName = (mainName != NULL && mainName[0] != '\0') ? mainName : "main.c";
    int extraIndex;

    OutputBegin();
    OutputHook = PendingOutputHook;
    OutputHookContext = PendingOutputHookContext;
    InputWaitHook = PendingInputWaitHook;
    InputWaitHookContext = PendingInputWaitHookContext;
    lilc_picoc_set_include_root(includeRoot);
    if (OpenStdinPipe() == 0 && stdinText != NULL && stdinText[0] != '\0') {
        lilc_picoc_feed_stdin(stdinText, (int)strlen(stdinText));
    }
    if (!keepStdinOpen) {
        lilc_picoc_close_stdin();
    }

    PicocInitialize(&pc, LILC_PICOC_STACK_SIZE);

    if (PicocPlatformSetExitPoint(&pc) == 0) {
        PicocIncludeAllSystemHeaders(&pc);
        for (extraIndex = 0; extraIndex < extraCount; extraIndex++) {
            if (extraNames != NULL && extraNames[extraIndex] != NULL && extraNames[extraIndex][0] != '\0') {
                PicocPlatformScanFile(&pc, extraNames[extraIndex]);
            }
        }
        PicocParse(&pc, parseName, source, (int)strlen(source), true, false, false, false);
        PicocCallMain(&pc, 0, NULL);
    }

    PicocCleanup(&pc);
    DestroyStdinPipe();
    lilc_picoc_set_include_root(NULL);
    OutputHook = NULL;
    OutputHookContext = NULL;
    InputWaitHook = NULL;
    InputWaitHookContext = NULL;
    output = OutputFinish();
    return output != NULL ? output : CopyString("lilC could not run this C program.\n");
}

static char *RunLocked(
    const char *source,
    const char *stdinText,
    int keepStdinOpen,
    const char *mainName,
    const char *const *extraNames,
    int extraCount,
    const char *includeRoot)
{
    char *output;

    if (source == NULL || source[0] == '\0') {
        return CopyString("Write some C code, then run it.\n");
    }

    pthread_mutex_lock(&RunnerMutex);
    output = RunWithCapture(source, stdinText, keepStdinOpen, mainName, extraNames, extraCount, includeRoot);
    pthread_mutex_unlock(&RunnerMutex);

    return output != NULL ? output : CopyString("lilC could not run this C program.\n");
}

char *lilc_picoc_run_source(const char *source)
{
    return RunLocked(source, NULL, 0, "main.c", NULL, 0, NULL);
}

char *lilc_picoc_run_source_with_stdin(const char *source, const char *stdin_text)
{
    return RunLocked(source, stdin_text, 0, "main.c", NULL, 0, NULL);
}

char *lilc_picoc_run_source_interactive(const char *source)
{
    return RunLocked(source, NULL, 1, "main.c", NULL, 0, NULL);
}

char *lilc_picoc_run_source_interactive_project(
    const char *source,
    const char *main_name,
    const char *const *extra_names,
    int extra_count,
    const char *include_root)
{
    return RunLocked(source, NULL, 1, main_name, extra_names, extra_count, include_root);
}

void lilc_picoc_free_output(char *output)
{
    free(output);
}
