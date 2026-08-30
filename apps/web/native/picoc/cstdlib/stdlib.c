/*  */
#include <stdlib.h>

#include "../interpreter.h"


static int Stdlib_ZeroValue = 0;


static void RequireCString(struct ParseState *Parser, const void *Pointer,
    const char *FuncName)
{
    if (Pointer == NULL)
        ProgramFail(Parser, "NULL pointer passed to %s()", FuncName);
}

void StdlibAtof(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    RequireCString(Parser, Param[0]->Val->Pointer, "atof");
    ReturnValue->Val->FP = atof(Param[0]->Val->Pointer);
}

void StdlibAtoi(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    RequireCString(Parser, Param[0]->Val->Pointer, "atoi");
    ReturnValue->Val->Integer = atoi(Param[0]->Val->Pointer);
}

void StdlibAtol(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    RequireCString(Parser, Param[0]->Val->Pointer, "atol");
    ReturnValue->Val->Integer = atol(Param[0]->Val->Pointer);
}

void StdlibStrtod(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->FP = strtod(Param[0]->Val->Pointer, Param[1]->Val->Pointer);
}

void StdlibStrtol(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = strtol(Param[0]->Val->Pointer,
        Param[1]->Val->Pointer, Param[2]->Val->Integer);
}

void StdlibStrtoul(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = strtoul(Param[0]->Val->Pointer,
        Param[1]->Val->Pointer, Param[2]->Val->Integer);
}

void StdlibMalloc(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    if (Param[0]->Val->Integer < 0)
        ProgramFail(Parser, "invalid allocation size");
    ReturnValue->Val->Pointer = malloc((size_t)Param[0]->Val->Integer);
}

void StdlibCalloc(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    if (Param[0]->Val->Integer < 0 || Param[1]->Val->Integer < 0)
        ProgramFail(Parser, "invalid allocation size");
    ReturnValue->Val->Pointer = calloc((size_t)Param[0]->Val->Integer,
        (size_t)Param[1]->Val->Integer);
}

void StdlibRealloc(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    if (Param[1]->Val->Integer < 0)
        ProgramFail(Parser, "invalid allocation size");
    ReturnValue->Val->Pointer = realloc(Param[0]->Val->Pointer,
        (size_t)Param[1]->Val->Integer);
}

void StdlibFree(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    free(Param[0]->Val->Pointer);
}

void StdlibRand(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = rand();
}

void StdlibSrand(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    srand(Param[0]->Val->Integer);
}

void StdlibAbort(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ProgramFail(Parser, "abort");
}

void StdlibExit(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    PlatformExit(Parser->pc, Param[0]->Val->Integer);
}

void StdlibGetenv(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
#ifdef LILC_IOS_HOST
    (void)Parser;
    (void)Param;
    (void)NumArgs;
    /* Do not leak host environment into learner programs. */
    ReturnValue->Val->Pointer = NULL;
#else
    ReturnValue->Val->Pointer = getenv(Param[0]->Val->Pointer);
#endif
}

void StdlibAssert(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    (void)ReturnValue;
    (void)NumArgs;
    if (Param[0]->Val->Integer == 0)
        ProgramFail(Parser, "assertion failed");
}

void StdlibSystem(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    (void)Param;
    (void)NumArgs;
    ProgramFail(Parser, "system() is not available in lilC local mode");
    ReturnValue->Val->Integer = -1;
}

#if 0
void StdlibBsearch(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Pointer = bsearch(Param[0]->Val->Pointer,
        Param[1]->Val->Pointer, Param[2]->Val->Integer, Param[3]->Val->Integer,
        (int (*)())Param[4]->Val->Pointer);
}
#endif

void StdlibAbs(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = abs(Param[0]->Val->Integer);
}

void StdlibLabs(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = labs(Param[0]->Val->Integer);
}

#if 0
void StdlibDiv(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = div(Param[0]->Val->Integer,
        Param[1]->Val->Integer);
}

void StdlibLdiv(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = ldiv(Param[0]->Val->Integer,
        Param[1]->Val->Integer);
}
#endif

#if 0
/* handy structure definitions */
const char StdlibDefs[] = "\
typedef struct { \
    int quot, rem; \
} div_t; \
\
typedef struct { \
    int quot, rem; \
} ldiv_t; \
";
#endif

/* all stdlib.h functions */
struct LibraryFunction StdlibFunctions[] =
{
    {StdlibAtof, "float atof(char *);"},
    {StdlibStrtod, "float strtod(char *,char **);"},
    {StdlibAtoi, "int atoi(char *);"},
    {StdlibAtol, "int atol(char *);"},
    {StdlibStrtol, "int strtol(char *,char **,int);"},
    {StdlibStrtoul, "int strtoul(char *,char **,int);"},
    {StdlibMalloc, "void *malloc(int);"},
    {StdlibCalloc, "void *calloc(int,int);"},
    {StdlibRealloc, "void *realloc(void *,int);"},
    {StdlibFree, "void free(void *);"},
    {StdlibRand, "int rand();"},
    {StdlibSrand, "void srand(int);"},
    {StdlibAbort, "void abort();"},
    {StdlibExit, "void exit(int);"},
    {StdlibGetenv, "char *getenv(char *);"},
    {StdlibSystem, "int system(char *);"},
/*    {StdlibBsearch, "void *bsearch(void *,void *,int,int,int (*)());"}, */
/*    {StdlibQsort, "void *qsort(void *,int,int,int (*)());"}, */
    {StdlibAbs, "int abs(int);"},
    {StdlibLabs, "int labs(int);"},
#if 0
    {StdlibDiv, "div_t div(int);"},
    {StdlibLdiv, "ldiv_t ldiv(int);"},
#endif
    {NULL, NULL}
};

struct LibraryFunction AssertFunctions[] =
{
    {StdlibAssert, "void assert(int);"},
    {NULL, NULL}
};

/* creates various system-dependent definitions */
void StdlibSetupFunc(Picoc *pc)
{
    /* define NULL, TRUE and FALSE */
    if (!VariableDefined(pc, TableStrRegister(pc, "NULL")))
        VariableDefinePlatformVar(pc, NULL, "NULL", &pc->IntType,
            (union AnyValue*)&Stdlib_ZeroValue, false);
}
