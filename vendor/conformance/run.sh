#!/bin/bash
# Builds the lilC C-conformance harness against the real PicoC engine and runs it.
set -e
cd "$(dirname "$0")/../.."

PICOC=lilC/Vendor/PicoC

clang -DLILC_IOS_HOST=1 -I "$PICOC" -o vendor/conformance/harness \
  vendor/conformance/runner.c \
  vendor/conformance/cases.c \
  "$PICOC"/lilc/lilc_picoc_runner.c \
  "$PICOC"/lilc/platform_lilc_ios.c \
  "$PICOC"/table.c "$PICOC"/lex.c "$PICOC"/parse.c \
  "$PICOC"/expression.c "$PICOC"/heap.c "$PICOC"/type.c \
  "$PICOC"/variable.c "$PICOC"/clibrary.c "$PICOC"/platform.c \
  "$PICOC"/include.c "$PICOC"/debug.c \
  "$PICOC"/cstdlib/*.c \
  2>/tmp/lilc_conformance_build.log || { echo "BUILD FAILED:"; cat /tmp/lilc_conformance_build.log; exit 1; }

grep -iE "error" /tmp/lilc_conformance_build.log || true

./vendor/conformance/harness "$@"
