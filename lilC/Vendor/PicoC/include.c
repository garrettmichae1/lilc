/* picoc include system - can emulate system includes from built-in libraries
 * or it can include and parse files if the system has files */

#include "picoc.h"
#include "interpreter.h"

#include <limits.h>

static int StddefNullValue = 0;
static int LimitsCharBit = CHAR_BIT;
static int LimitsSCharMin = SCHAR_MIN;
static int LimitsSCharMax = SCHAR_MAX;
static int LimitsUCharMax = UCHAR_MAX;
static int LimitsCharMin = CHAR_MIN;
static int LimitsCharMax = CHAR_MAX;
static int LimitsShrtMin = SHRT_MIN;
static int LimitsShrtMax = SHRT_MAX;
static int LimitsUShrtMax = USHRT_MAX;
static int LimitsIntMin = INT_MIN;
static int LimitsIntMax = INT_MAX;
static unsigned int LimitsUIntMax = UINT_MAX;
static long LimitsLongMin = LONG_MIN;
static long LimitsLongMax = LONG_MAX;
static unsigned long LimitsULongMax = ULONG_MAX;

const char StddefDefs[] =
    "typedef int ptrdiff_t; typedef unsigned int size_t;";

const char StdintDefs[] =
    "typedef char int8_t; typedef short int16_t; typedef int int32_t; "
    "typedef unsigned char uint8_t; typedef unsigned short uint16_t; "
    "typedef unsigned int uint32_t; typedef int intptr_t; "
    "typedef unsigned int uintptr_t;";

void StddefSetupFunc(Picoc *pc)
{
    if (!VariableDefined(pc, TableStrRegister(pc, "NULL")))
        VariableDefinePlatformVar(pc, NULL, "NULL", &pc->IntType,
            (union AnyValue *)&StddefNullValue, false);
}

void LimitsSetupFunc(Picoc *pc)
{
    VariableDefinePlatformVar(pc, NULL, "CHAR_BIT", &pc->IntType,
        (union AnyValue *)&LimitsCharBit, false);
    VariableDefinePlatformVar(pc, NULL, "SCHAR_MIN", &pc->IntType,
        (union AnyValue *)&LimitsSCharMin, false);
    VariableDefinePlatformVar(pc, NULL, "SCHAR_MAX", &pc->IntType,
        (union AnyValue *)&LimitsSCharMax, false);
    VariableDefinePlatformVar(pc, NULL, "UCHAR_MAX", &pc->IntType,
        (union AnyValue *)&LimitsUCharMax, false);
    VariableDefinePlatformVar(pc, NULL, "CHAR_MIN", &pc->IntType,
        (union AnyValue *)&LimitsCharMin, false);
    VariableDefinePlatformVar(pc, NULL, "CHAR_MAX", &pc->IntType,
        (union AnyValue *)&LimitsCharMax, false);
    VariableDefinePlatformVar(pc, NULL, "SHRT_MIN", &pc->IntType,
        (union AnyValue *)&LimitsShrtMin, false);
    VariableDefinePlatformVar(pc, NULL, "SHRT_MAX", &pc->IntType,
        (union AnyValue *)&LimitsShrtMax, false);
    VariableDefinePlatformVar(pc, NULL, "USHRT_MAX", &pc->IntType,
        (union AnyValue *)&LimitsUShrtMax, false);
    VariableDefinePlatformVar(pc, NULL, "INT_MIN", &pc->IntType,
        (union AnyValue *)&LimitsIntMin, false);
    VariableDefinePlatformVar(pc, NULL, "INT_MAX", &pc->IntType,
        (union AnyValue *)&LimitsIntMax, false);
    VariableDefinePlatformVar(pc, NULL, "UINT_MAX", &pc->UnsignedIntType,
        (union AnyValue *)&LimitsUIntMax, false);
    VariableDefinePlatformVar(pc, NULL, "LONG_MIN", &pc->LongType,
        (union AnyValue *)&LimitsLongMin, false);
    VariableDefinePlatformVar(pc, NULL, "LONG_MAX", &pc->LongType,
        (union AnyValue *)&LimitsLongMax, false);
    VariableDefinePlatformVar(pc, NULL, "ULONG_MAX", &pc->UnsignedLongType,
        (union AnyValue *)&LimitsULongMax, false);
}

/* initialize the built-in include libraries */
void IncludeInit(Picoc *pc)
{
    IncludeRegister(pc, "ctype.h", NULL, &StdCtypeFunctions[0], NULL);
    IncludeRegister(pc, "errno.h", &StdErrnoSetupFunc, NULL, NULL);
# ifndef NO_FP
    IncludeRegister(pc, "math.h", &MathSetupFunc, &MathFunctions[0], NULL);
# endif
    IncludeRegister(pc, "stdbool.h", &StdboolSetupFunc, NULL, StdboolDefs);
    IncludeRegister(pc, "stdio.h", &StdioSetupFunc, &StdioFunctions[0], StdioDefs);
    IncludeRegister(pc, "stdlib.h", &StdlibSetupFunc, &StdlibFunctions[0], NULL);
    IncludeRegister(pc, "string.h", &StringSetupFunc, &StringFunctions[0], NULL);
    IncludeRegister(pc, "time.h", &StdTimeSetupFunc, &StdTimeFunctions[0], StdTimeDefs);
    IncludeRegister(pc, "stddef.h", &StddefSetupFunc, NULL, StddefDefs);
    IncludeRegister(pc, "stdint.h", NULL, NULL, StdintDefs);
    IncludeRegister(pc, "limits.h", &LimitsSetupFunc, NULL, NULL);
    IncludeRegister(pc, "assert.h", NULL, &AssertFunctions[0], NULL);
# if !defined(WIN32) && !defined(LILC_IOS_HOST)
    IncludeRegister(pc, "unistd.h", &UnistdSetupFunc, &UnistdFunctions[0], UnistdDefs);
# endif
}

/* clean up space used by the include system */
void IncludeCleanup(Picoc *pc)
{
    struct IncludeLibrary *ThisInclude = pc->IncludeLibList;
    struct IncludeLibrary *NextInclude;

    while (ThisInclude != NULL) {
        NextInclude = ThisInclude->NextLib;
        HeapFreeMem(pc, ThisInclude);
        ThisInclude = NextInclude;
    }

    pc->IncludeLibList = NULL;
}

/* register a new build-in include file */
void IncludeRegister(Picoc *pc, const char *IncludeName,
    void (*SetupFunction)(Picoc *pc), struct LibraryFunction *FuncList,
    const char *SetupCSource)
{
    struct IncludeLibrary *NewLib = HeapAllocMem(pc, sizeof(struct IncludeLibrary));
    NewLib->IncludeName = TableStrRegister(pc, IncludeName);
    NewLib->SetupFunction = SetupFunction;
    NewLib->FuncList = FuncList;
    NewLib->SetupCSource = SetupCSource;
    NewLib->NextLib = pc->IncludeLibList;
    pc->IncludeLibList = NewLib;
}

/* include all of the system headers */
void PicocIncludeAllSystemHeaders(Picoc *pc)
{
    struct IncludeLibrary *ThisInclude = pc->IncludeLibList;

    for (; ThisInclude != NULL; ThisInclude = ThisInclude->NextLib)
        IncludeFile(pc, ThisInclude->IncludeName);
}

/* include one of a number of predefined libraries, or perhaps an actual file */
void IncludeFile(Picoc *pc, char *FileName)
{
    struct IncludeLibrary *LInclude;

    /* scan for the include file name to see if it's in our list
        of predefined includes */
    for (LInclude = pc->IncludeLibList; LInclude != NULL;
            LInclude = LInclude->NextLib) {
        if (strcmp(LInclude->IncludeName, FileName) == 0) {
            /* found it - protect against multiple inclusion */
            if (!VariableDefined(pc, FileName)) {
                VariableDefine(pc, NULL, FileName, NULL, &pc->VoidType, false);

                /* run an extra startup function if there is one */
                if (LInclude->SetupFunction != NULL)
                    (*LInclude->SetupFunction)(pc);

                /* parse the setup C source code - may define types etc. */
                if (LInclude->SetupCSource != NULL)
                    PicocParse(pc, FileName, LInclude->SetupCSource,
                        strlen(LInclude->SetupCSource), true, true, false, false);

                /* set up the library functions */
                if (LInclude->FuncList != NULL)
                    LibraryAdd(pc, LInclude->FuncList);
            }

            return;
        }
    }

    /* not a predefined file, read a real file */
    PicocPlatformScanFile(pc, FileName);
}
