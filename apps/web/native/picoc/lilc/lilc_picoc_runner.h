#ifndef LILC_PICOC_RUNNER_H
#define LILC_PICOC_RUNNER_H

#include <stdio.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*lilc_output_hook)(const char *bytes, int length, void *context);

/* Notifies the host that the running program is blocked waiting for stdin
   (waiting != 0) or has just resumed after receiving input (waiting == 0). */
typedef void (*lilc_input_wait_hook)(int waiting, void *context);

void lilc_picoc_set_output_hook(lilc_output_hook hook, void *context);
void lilc_picoc_set_input_wait_hook(lilc_input_wait_hook hook, void *context);
void lilc_picoc_set_include_root(const char *path);
int lilc_picoc_feed_stdin(const char *bytes, int length);
void lilc_picoc_close_stdin(void);
void lilc_picoc_request_stop(void);

char *lilc_picoc_run_source(const char *source);
char *lilc_picoc_run_source_with_stdin(const char *source, const char *stdin_text);
char *lilc_picoc_run_source_interactive(const char *source);
char *lilc_picoc_run_source_interactive_project(
    const char *source,
    const char *main_name,
    const char *const *extra_names,
    int extra_count,
    const char *include_root);
void lilc_picoc_free_output(char *output);

FILE *LilCStdinFile(void);

/* Blocking stdin reads used by the platform layer. They fire the input-wait
   hook when the program has to pause for the user, so the UI can show a
   "waiting for input" state that matches a real terminal. */
char *LilCReadLine(char *buf, int max_len);
int LilCReadChar(void);

/* Restrict fopen/remove/rename to the current project folder. */
int LilCProjectPathIsSafe(const char *FileName);
int LilCResolveProjectPath(const char *FileName, char *Out, size_t OutSize);
FILE *LilCFopenProjectFile(const char *FileName, const char *Mode);

/* Blocks until stdin has data ready (or is closed/stopped), firing the
   input-wait hook while paused. Call this immediately before a blocking
   fscanf/fgets/fgetc on the captured stdin so the UI reflects the wait. */
void LilCWaitForInput(void);

#ifdef __cplusplus
}
#endif

#endif
