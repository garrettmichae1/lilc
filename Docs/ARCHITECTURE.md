# Architecture

lilC is a local PicoC environment. Layers already in the tree:

- **Presentation** — SwiftUI (`ContentView`, `SettingsScreen`, `CCodeEditor`). Agent screens exist but are gated off.
- **Domain** — `LocalCWorkspace`, `CDiagnostics`, appearance, `LegalURLs`.
- **Application / Infrastructure** — hidden agent session and HTTPS client. Not shown in this release.
- **Vendor/PicoC** — interpreter plus the iOS host in `lilc/`.

The shipping UI never opens a remote shell. SSH, VNC, and server profiles were removed because Home could not reach them.

Boundaries that matter for contributors:

- PicoC C API: `lilC/Vendor/PicoC/lilc/lilc_picoc_runner.h`
- Diagnostics: `CDiagnosticFormatter` in `CDiagnostics.swift`
- Editor: `CCodeEditor.swift`

Keep those surfaces small. Do not add a second architecture.
