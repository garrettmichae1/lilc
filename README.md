# lilC

lilC is an on-device **C learner for iPhone**. You write C in an editor, press Run, and PicoC interprets the program on the device. There is no remote Linux VM, no SSH session, and no cloud compiler.

The runtime is **PicoC**, a small interpreter (BSD 3-Clause, vendored in this repo). It is **not** GCC or Clang. Most beginner programs work. Some advanced C — a full standard library, or extras only a desktop compiler supports — will not.

## Open in Xcode

1. Clone this repository.
2. Open `lilC.xcodeproj` (Xcode 16+, iOS 17).
3. Select the **lilC** scheme and a simulator or device.
4. Build and run.

```bash
xcodebuild -scheme lilC -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## What ships

- Editor with find-in-file, symbol-friendly keyboard, and jump-to-error
- Run / Stop, stdin while a program waits, PicoC output
- Files and projects on this iPhone, including erase-all
- Settings: Light / Dark, an honest PicoC vs GCC note, legal HTTPS links

Agent chat is **compiled into the app but hidden** in this release (`AgentRuntimeConfig.surfacesVisibleInThisRelease = false`). Do not turn that flag on in a PR unless maintainers ask for it.

## Legal pages (GitHub Pages)

These URLs are used by Settings and App Store review. Do not break them:

- https://garrettmichae1.github.io/lilc/
- https://garrettmichae1.github.io/lilc/privacy.html
- https://garrettmichae1.github.io/lilc/terms.html

The HTML lives at the **repository root** (`index.html`, `privacy.html`, `terms.html`, `styles.css`) so GitHub Pages keeps serving the same paths.

## Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a PicoC library, a diagnostic, or an editor extra, and how to send a pull request.

## License

lilC source (except vendored PicoC) is **Apache License 2.0**. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

You may use, modify, and fork the **code**, including in other projects. You **may not** publish or sell the lilC app (same or confusing name, icon, or bundle id) on the App Store or any store. Forks must be renamed. See [TRADEMARKS.md](TRADEMARKS.md).

PicoC remains BSD 3-Clause (`lilC/Vendor/PicoC/LICENSE`).
