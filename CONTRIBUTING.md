# Contributing to lilC

Thanks for wanting to improve lilC. This is an on-device PicoC learner for iPhone. Pull requests that extend the **editor**, **diagnostics**, or **PicoC runtime** are welcome. Please do not change shipping behavior unless that is the point of the PR.

## Ground rules

- **Do not enable Agent UI.** `AgentRuntimeConfig.surfacesVisibleInThisRelease` must stay `false`. Agent code stays in the tree for a later release; do not add an Agent tab, Settings Agent section, or IAP surfaces to the shipping UI.
- **Do not reintroduce SSH, VNC, remote Linux VMs, or SwiftTerm.** Local C mode is the product.
- **Do not commit secrets.** No `.dev.vars`, API keys, Keychain dumps, or account files.
- Forks of the *code* are fine. Do not publish an App Store clone named lilC. See `TRADEMARKS.md`.
- Keep PicoC vendor sources readable; do not “clean” them into unreadability.

## Open the project

1. Install Xcode 16+ (iOS 17 SDK).
2. Open `lilC.xcodeproj`.
3. Select the **lilC** scheme and an iPhone simulator.
4. Build and run.

```bash
xcodebuild -scheme lilC -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme lilC -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## How to add a PicoC library

PicoC libraries live under `lilC/Vendor/PicoC/cstdlib/` and are registered in `lilC/Vendor/PicoC/include.c` via `IncludeRegister`.

1. Add a `.c` file next to the existing cstdlib sources (follow `stdio.c` / `string.c`).
2. Export a `LibraryFunction` table and any setup function.
3. Register the header name in `IncludeInit` in `include.c`.
4. Add the `.c` file to the **lilC** target in `lilC.xcodeproj` (Sources build phase).
5. Keep host isolation: no `system()`, no reading files outside the project folder, no leaking host environment. See `platform_lilc_ios.c` and `lilc_picoc_runner.c`.
6. Add a unit test in `lilCTests/lilCTests.swift` that runs a small program through `LocalCRunner.run`.
7. Optionally extend `vendor/conformance/` if the change is language-level.

The iOS runner is `lilC/Vendor/PicoC/lilc/`. Prefer extending that layer over rewriting upstream PicoC.

## How to add a diagnostic

Friendly errors are mapped in `lilC/Domain/CDiagnostics.swift` (`CDiagnosticFormatter.advice(for:wholeOutput:)`).

1. Capture the raw PicoC / runner message (the test suite prints it on failure).
2. Add a `text.contains(...)` branch that returns `syntax` / `name` / `type` / `runtime` / `project` / `unsupported` with a learner-facing title, explanation, and suggestion.
3. Add the raw string to `picoCAndRunnerErrorCatalog` in `lilCTests.swift`.
4. Add a focused `@Test` that runs a small program or feeds the raw message.

Jump-to-error is `CDiagnosticJump` plus `LocalCWorkspace.revealErrorJump()`. Do not change caret mapping unless you add tests.

## How to add an editor extra

The editor is `lilC/Presentation/CCodeEditor.swift` (`UIViewRepresentable` over `UITextView`). Find-in-file is `EditorSearch` in the same file. The local IDE chrome (Run/Stop, find bar, stdin, tabs) is in `ContentView.swift` (`LocalModeScreen`).

Keep extras local to those types. Do not couple the editor to Agent, network, or a second text engine.

## Tests

`lilCTests` uses Swift Testing (`@Test`, `#expect`). The suite is `@Suite(.serialized)` because PicoC is process-global. Tests must pass. If you change PicoC or diagnostics, extend coverage instead of weakening assertions.

## Code layout

Existing folders are enough. Do not invent a new architecture:

| Folder | What belongs there |
| --- | --- |
| `lilC/Domain` | Workspace, diagnostics, appearance, legal URLs, agent models (hidden) |
| `lilC/Presentation` | SwiftUI screens and the code editor |
| `lilC/Application` | Agent session (compiled, not shown) |
| `lilC/Infrastructure` | Keychain and HTTP client for the hidden agent |
| `lilC/Vendor/PicoC` | Vendored PicoC + lilC iOS host |

Protocols already exist at the agent HTTP boundary. Do not add protocols “for SOLID” unless you are introducing a real second implementation.

## Pull requests

1. Fork [garrettmichae1/lilc](https://github.com/garrettmichae1/lilc).
2. Branch from `main`.
3. Keep GitHub Pages files at the repo root (`index.html`, `privacy.html`, `terms.html`, `styles.css`). Those URLs are live legal links.
4. Describe what you changed and how you tested (simulator is enough).
5. One concern per PR when you can.

Questions: open an issue, or email support@lilc.app.
