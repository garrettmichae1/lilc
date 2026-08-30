/*
 * lilC C-language conformance harness.
 *
 * Compiles against the real PicoC engine (the same sources the app ships) and
 * runs a battery of C programs, comparing captured stdout against an expected
 * string. Each case is tagged with a category so we can see coverage gaps by
 * area of the language.
 *
 * Build + run via vendor/conformance/run.sh
 */
#include "../../lilC/Vendor/PicoC/lilc/lilc_picoc_runner.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const char *category;
    const char *name;
    const char *source;
    const char *expected; /* exact stdout expected */
} TestCase;

/* Defined in cases.c */
extern const TestCase kCases[];
extern const int kCaseCount;

static char *RunCapture(const char *source) {
    /* Non-interactive: stdin is closed immediately. */
    char *out = lilc_picoc_run_source(source);
    return out;
}

static int StringsEqual(const char *a, const char *b) {
    if (a == NULL) a = "";
    if (b == NULL) b = "";
    return strcmp(a, b) == 0;
}

static void PrintEscaped(const char *label, const char *s) {
    printf("    %s: \"", label);
    if (s == NULL) { printf("(null)\""); printf("\n"); return; }
    for (const char *p = s; *p; p++) {
        if (*p == '\n') printf("\\n");
        else if (*p == '\t') printf("\\t");
        else if (*p == '"') printf("\\\"");
        else putchar(*p);
    }
    printf("\"\n");
}

int main(int argc, char **argv) {
    int verbose = (argc > 1 && strcmp(argv[1], "-v") == 0);
    int onlyFails = (argc > 1 && strcmp(argv[1], "-f") == 0);

    int total = 0, passed = 0;

    /* Per-category tallies. */
    #define MAX_CATS 64
    const char *catNames[MAX_CATS];
    int catTotal[MAX_CATS];
    int catPass[MAX_CATS];
    int catCount = 0;

    for (int i = 0; i < kCaseCount; i++) {
        const TestCase *tc = &kCases[i];

        int ci = -1;
        for (int c = 0; c < catCount; c++) {
            if (strcmp(catNames[c], tc->category) == 0) { ci = c; break; }
        }
        if (ci < 0 && catCount < MAX_CATS) {
            ci = catCount++;
            catNames[ci] = tc->category;
            catTotal[ci] = 0;
            catPass[ci] = 0;
        }

        char *out = RunCapture(tc->source);
        int ok = StringsEqual(out, tc->expected);

        total++;
        if (ok) passed++;
        if (ci >= 0) { catTotal[ci]++; if (ok) catPass[ci]++; }

        if ((!ok && !onlyFails) || (!ok) || verbose) {
            if (!ok || verbose) {
                printf("[%s] %-28s %s\n", ok ? "PASS" : "FAIL", tc->name, tc->category);
                if (!ok || verbose) {
                    PrintEscaped("expected", tc->expected);
                    PrintEscaped("actual  ", out);
                }
            }
        }

        lilc_picoc_free_output(out);
    }

    printf("\n=================== CATEGORY COVERAGE ===================\n");
    for (int c = 0; c < catCount; c++) {
        double pct = catTotal[c] ? (100.0 * catPass[c] / catTotal[c]) : 0.0;
        printf("  %-26s %3d/%-3d  %5.1f%%\n", catNames[c], catPass[c], catTotal[c], pct);
    }
    printf("========================================================\n");
    printf("TOTAL: %d/%d passed (%.1f%%)\n", passed, total,
           total ? 100.0 * passed / total : 0.0);

    return passed == total ? 0 : 1;
}
