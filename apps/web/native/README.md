Vendored PicoC (BSD 3-Clause), copied from the iPhone app’s `lilC/Vendor/PicoC`.

The browser host is `../lilc_picoc_runner_web.c`. One Emscripten-only ifdef in
`picoc/cstdlib/stdio.c` covers opaque `FILE` (`sizeof(FILE)` is invalid in
Emscripten libc). That change is not in the iOS tree.
