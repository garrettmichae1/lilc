#!/bin/sh
# Compile vendored PicoC + the web runner to WASM with Emscripten.
# Usage: ./native/build-wasm.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PICOC="$ROOT/native/picoc"
OUT="$ROOT/public"
mkdir -p "$OUT"

if ! command -v emcc >/dev/null 2>&1; then
  if [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/emsdk/emsdk_env.sh"
  fi
fi

if ! command -v emcc >/dev/null 2>&1; then
  echo "emcc not found. Install Emscripten (see README) and retry." >&2
  exit 1
fi

SOURCES="
$PICOC/table.c
$PICOC/lex.c
$PICOC/parse.c
$PICOC/expression.c
$PICOC/heap.c
$PICOC/type.c
$PICOC/variable.c
$PICOC/clibrary.c
$PICOC/platform.c
$PICOC/include.c
$PICOC/debug.c
$PICOC/cstdlib/ctype.c
$PICOC/cstdlib/errno.c
$PICOC/cstdlib/math.c
$PICOC/cstdlib/stdbool.c
$PICOC/cstdlib/stdio.c
$PICOC/cstdlib/stdlib.c
$PICOC/cstdlib/string.c
$PICOC/cstdlib/time.c
$PICOC/lilc/platform_lilc_ios.c
$ROOT/native/lilc_picoc_runner_web.c
"

# LILC_IOS_HOST reuses the iOS host ifdefs in vendored PicoC (stdio, getenv, step limit).
# UNIX_HOST satisfies platform.h. The web runner replaces pipes/pthreads.
emcc -O2 \
  $SOURCES \
  -I"$PICOC" \
  -I"$PICOC/lilc" \
  -DLILC_IOS_HOST=1 \
  -DUNIX_HOST=1 \
  -s ASYNCIFY=1 \
  -s ASYNCIFY_STACK_SIZE=1048576 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s MODULARIZE=1 \
  -s EXPORT_ES6=1 \
  -s EXPORT_NAME=createPicoC \
  -s ENVIRONMENT=web \
  -s FILESYSTEM=1 \
  -s EXPORTED_FUNCTIONS='["_lilc_picoc_run_source","_lilc_picoc_run_source_with_stdin","_lilc_picoc_run_source_interactive","_lilc_picoc_run_source_interactive_project","_lilc_picoc_feed_stdin","_lilc_picoc_close_stdin","_lilc_picoc_request_stop","_lilc_picoc_free_output","_malloc","_free"]' \
  -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","UTF8ToString","stringToUTF8","lengthBytesUTF8","FS","HEAPU8"]' \
  -s STACK_SIZE=524288 \
  -o "$OUT/picoc.js"

echo "Wrote $OUT/picoc.js and $OUT/picoc.wasm"
