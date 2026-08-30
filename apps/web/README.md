# lilC for the web

A TypeScript copy of the **lilC iPhone app**: a local C learner that runs in the browser. Write `.c` / `.h` files, press Run, and **PicoC** interprets the program with WebAssembly. There is no server compiler, no account, and no Agent.

This folder is the source of truth for the web app (`/Users/garrettwoodside/Desktop/lilCWeb`). The shipping GitHub Pages site is the built static files at **`web/`** in [garrettmichae1/lilc](https://github.com/garrettmichae1/lilc):

**https://garrettmichae1.github.io/lilc/web/**

The iPhone app is unchanged. Legal pages stay at the repository root (`privacy.html`, `terms.html`).

## What ships

- Home: Open editor, projects, new file, open, delete, settings
- Editor: Run / Stop, stdin while waiting, output, find in file, jump to error
- C symbol bar (`{ } ( ) ; * &`), indent / outdent, format (4-space C indent), one keyboard dismiss control
- Light / Dark, PicoC vs GCC note, erase all files, Privacy / Terms
- Files persist in this browser (IndexedDB, with localStorage backup)
- No Agent, no C Manual, no IAP, no SSH/VM, no analytics

The runtime is **PicoC** (BSD 3-Clause), the same vendored interpreter as iOS, compiled to WASM. It is **not** GCC or Clang.

## Develop

```bash
npm install
npm run wasm      # needs emcc; see PicoC / WASM below
npm test
npm run dev
```

`npm run build` emits static files in `dist/` with **relative** asset paths so GitHub project Pages can host the app at `/lilc/web/`.

Publish into the iOS/legal repo without touching Swift:

```bash
sh scripts/publish-to-repo.sh /Users/garrettwoodside/Desktop/lilC
```

That copies `dist/` → `lilC/web/` (Pages) and this source → `lilC/apps/web/` (versioned TypeScript).

## PicoC / WASM

`native/picoc` is a copy of `lilC/Vendor/PicoC` from the iPhone repo. The browser host is `native/lilc_picoc_runner_web.c` (MEMFS + Emscripten ASYNCIFY for stdin). Vendored PicoC sources are not edited in the iOS tree.

```bash
# Python 3.10+ is required by emsdk
export EMSDK_PYTHON="$(uv python find 3.12)"   # or another 3.10+ interpreter
. "$HOME/emsdk/emsdk_env.sh"
npm run wasm
```

This writes `public/picoc.js` and `public/picoc.wasm`. Without those files the UI still loads; Run reports that the engine could not start.

## Architecture

| Layer | Path |
| --- | --- |
| Domain | `src/domain/` — workspace, diagnostics, indent, appearance, storage |
| PicoC adapter | `src/pico/runner.ts` + `native/` |
| Presentation | `src/ui/` — screens and DOM |

Keep those surfaces small. Do not add a backend.

## License

lilC source (except vendored PicoC) is **Apache License 2.0**. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

You may use and fork the **code**. You **may not** sell Garrett Woodside’s lilC product (same or confusing name, icon, or listing). This web app is a free student resource. See [TRADEMARKS.md](TRADEMARKS.md).

PicoC remains BSD 3-Clause (`native/picoc/LICENSE`).
