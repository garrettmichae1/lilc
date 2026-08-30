/*
 * Web host for the vendored PicoC interpreter.
 * Same public API as the iOS runner, but stdin uses MEMFS + emscripten_sleep
 * (ASYNCIFY) instead of POSIX pipes/pthreads so it can run in a browser.
 */
#include "picoc/lilc/lilc_picoc_runner.h"
#include "picoc/picoc.h"

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LILC_PICOC_STACK_SIZE (128000 * 4)
#define LILC_OUTPUT_LIMIT (128 * 1024)
#define LILC_STEP_LIMIT 200000
#define LILC_STDIN_PATH "/tmp/lilc-stdin"

static char *OutputBuffer = NULL;
static size_t OutputLength = 0;
static size_t OutputCapacity = 0;
static unsigned int StepCount = 0;
static int ExecutionStopped = 0;
static int StoppedByUser = 0;
static FILE *StdinFile = NULL;
static int StdinClosed = 0;
static lilc_output_hook PendingOutputHook = NULL;
static void *PendingOutputHookContext = NULL;
static lilc_output_hook OutputHook = NULL;
static void *OutputHookContext = NULL;
static lilc_input_wait_hook PendingInputWaitHook = NULL;
static void *PendingInputWaitHookContext = NULL;
static lilc_input_wait_hook InputWaitHook = NULL;
static void *InputWaitHookContext = NULL;

#ifdef __EMSCRIPTEN__
EM_JS(void, lilc_js_output, (const char *bytes, int length), {
    const text = UTF8ToString(bytes, length);
    if (Module.lilcOnOutput) {
        Module.lilcOnOutput(text);
    }
});

EM_JS(void, lilc_js_waiting, (int waiting), {
    if (Module.lilcOnWaiting) {
        Module.lilcOnWaiting(waiting !== 0);
    }
});
#else
static void lilc_js_output(const char *bytes, int length)
{
    (void)bytes;
    (void)length;
}

static void lilc_js_waiting(int waiting)
{
    (void)waiting;
}
#endif

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

static void DestroyStdinFile(void)
{
    if (StdinFile != NULL) {
        fclose(StdinFile);
        StdinFile = NULL;
    }
    StdinClosed = 1;
    remove(LILC_STDIN_PATH);
}

static int OpenStdinFile(void)
{
    DestroyStdinFile();
    StdinFile = fopen(LILC_STDIN_PATH, "w+");
    if (StdinFile == NULL) {
        return -1;
    }
    setvbuf(StdinFile, NULL, _IONBF, 0);
    StdinClosed = 0;
    return 0;
}

static int StdinHasUnreadData(void)
{
    long pos;
    long end;

    if (StdinFile == NULL) {
        return 0;
    }
    pos = ftell(StdinFile);
    if (pos < 0) {
        return 0;
    }
    if (fseek(StdinFile, 0, SEEK_END) != 0) {
        return 0;
    }
    end = ftell(StdinFile);
    fseek(StdinFile, pos, SEEK_SET);
    return end > pos;
}

FILE *LilCStdinFile(void)
{
    return StdinFile != NULL ? StdinFile : stdin;
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

void LilCWaitForInput(void)
{
    int notifiedWaiting = 0;

    for (;;) {
        if (StoppedByUser || ExecutionStopped) {
            break;
        }
        if (StdinHasUnreadData()) {
            break;
        }
        if (StdinClosed) {
            break;
        }
        if (!notifiedWaiting) {
            notifiedWaiting = 1;
            if (InputWaitHook != NULL) {
                InputWaitHook(1, InputWaitHookContext);
            }
            lilc_js_waiting(1);
        }
#ifdef __EMSCRIPTEN__
        emscripten_sleep(40);
#else
        break;
#endif
    }

    if (notifiedWaiting) {
        if (InputWaitHook != NULL) {
            InputWaitHook(0, InputWaitHookContext);
        }
        lilc_js_waiting(0);
    }
}

char *LilCReadLine(char *buf, int max_len)
{
    if (buf == NULL || max_len <= 1) {
        return NULL;
    }
    LilCWaitForInput();
    if (StdinFile == NULL) {
        return NULL;
    }
    return fgets(buf, max_len, StdinFile);
}

int LilCReadChar(void)
{
    LilCWaitForInput();
    if (StdinFile == NULL) {
        return EOF;
    }
    return fgetc(StdinFile);
}

int lilc_picoc_feed_stdin(const char *bytes, int length)
{
    long pos;
    size_t written;

    if (bytes == NULL || length <= 0 || StdinFile == NULL || StdinClosed) {
        return -1;
    }
    pos = ftell(StdinFile);
    if (fseek(StdinFile, 0, SEEK_END) != 0) {
        return -1;
    }
    written = fwrite(bytes, 1, (size_t)length, StdinFile);
    fflush(StdinFile);
    if (pos >= 0) {
        fseek(StdinFile, pos, SEEK_SET);
    }
    return written == (size_t)length ? 0 : -1;
}

void lilc_picoc_close_stdin(void)
{
    StdinClosed = 1;
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

    if (incomingLength > 0) {
        lilc_js_output(OutputBuffer + OutputLength - incomingLength, (int)incomingLength);
    }
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
    if (OpenStdinFile() == 0 && stdinText != NULL && stdinText[0] != '\0') {
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
    DestroyStdinFile();
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
    if (source == NULL || source[0] == '\0') {
        return CopyString("Write some C code, then run it.\n");
    }
    return RunWithCapture(source, stdinText, keepStdinOpen, mainName, extraNames, extraCount, includeRoot);
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
