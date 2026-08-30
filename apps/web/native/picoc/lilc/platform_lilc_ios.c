#include "../picoc.h"
#include "../interpreter.h"
#include "lilc_picoc_runner.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void LilCOutputAppend(const char *Bytes, int Length);

static char IncludeRoot[1024];

void lilc_picoc_set_include_root(const char *path)
{
    if (path == NULL || path[0] == '\0') {
        IncludeRoot[0] = '\0';
        return;
    }
    strncpy(IncludeRoot, path, sizeof(IncludeRoot) - 1);
    IncludeRoot[sizeof(IncludeRoot) - 1] = '\0';
}

static int PathIsSafe(const char *name)
{
    if (name == NULL || name[0] == '\0' || name[0] == '/') {
        return 0;
    }
    if (strstr(name, "..") != NULL) {
        return 0;
    }
    return 1;
}

int LilCProjectPathIsSafe(const char *FileName)
{
    return PathIsSafe(FileName) && IncludeRoot[0] != '\0';
}

int LilCResolveProjectPath(const char *FileName, char *Out, size_t OutSize)
{
    if (!LilCProjectPathIsSafe(FileName) || Out == NULL || OutSize == 0) {
        return -1;
    }
    snprintf(Out, OutSize, "%s/%s", IncludeRoot, FileName);
    return 0;
}

FILE *LilCFopenProjectFile(const char *FileName, const char *Mode)
{
    char fullPath[2048];
    if (Mode == NULL || LilCResolveProjectPath(FileName, fullPath, sizeof(fullPath)) != 0) {
        return NULL;
    }
    return fopen(fullPath, Mode);
}

void PlatformInit(Picoc *pc)
{
    (void)pc;
}

void PlatformCleanup(Picoc *pc)
{
    (void)pc;
}

char *PlatformGetLine(char *Buf, int MaxLen, const char *Prompt)
{
    (void)Prompt;
    if (Buf == NULL || MaxLen <= 1) {
        return NULL;
    }
    return LilCReadLine(Buf, MaxLen);
}

int PlatformGetCharacter()
{
    return LilCReadChar();
}

void PlatformPutc(unsigned char OutCh, union OutputStreamInfo *Stream)
{
    (void)Stream;
    LilCOutputAppend((const char *)&OutCh, 1);
}

char *PlatformReadFile(Picoc *pc, const char *FileName)
{
    char fullPath[2048];
    FILE *file;
    long size;
    char *data;
    size_t readCount;

    if (!PathIsSafe(FileName) || IncludeRoot[0] == '\0') {
        ProgramFailNoParser(pc, "cannot include '%s' outside this project folder", FileName != NULL ? FileName : "");
        return NULL;
    }

    snprintf(fullPath, sizeof(fullPath), "%s/%s", IncludeRoot, FileName);
    file = fopen(fullPath, "rb");
    if (file == NULL) {
        ProgramFailNoParser(pc, "cannot open include file '%s'", FileName);
        return NULL;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        ProgramFailNoParser(pc, "cannot read include file '%s'", FileName);
        return NULL;
    }
    size = ftell(file);
    if (size < 0 || size > 512 * 1024) {
        fclose(file);
        ProgramFailNoParser(pc, "include file '%s' is too large", FileName);
        return NULL;
    }
    rewind(file);

    data = malloc((size_t)size + 1);
    if (data == NULL) {
        fclose(file);
        ProgramFailNoParser(pc, "out of memory reading '%s'", FileName);
        return NULL;
    }
    readCount = fread(data, 1, (size_t)size, file);
    fclose(file);
    data[readCount] = '\0';
    return data;
}

void PicocPlatformScanFile(Picoc *pc, const char *FileName)
{
    char *source = PlatformReadFile(pc, FileName);
    if (source == NULL) {
        return;
    }
    PicocParse(pc, FileName, source, (int)strlen(source), true, false, true, false);
}

void PlatformExit(Picoc *pc, int ExitVal)
{
    pc->PicocExitValue = ExitVal;
    longjmp(pc->PicocExitBuf, 1);
}

void PlatformLibraryInit(Picoc *pc)
{
    (void)pc;
}
