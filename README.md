# 🌸 Sakura Switch

**Sakura Switch** is an open-source, unsigned macOS window switcher — a lightweight Alt-Tab
replacement that lists *windows* (not just apps) with fuzzy search, live thumbnails and
keyboard-first navigation, wrapped in a native, frosted-glass UI.

> 将窗口（而非应用）作为切换单位的 macOS 窗口切换器。按住 `⌥ Tab` 唤起，键入即搜，
> 回车切换 —— 像原生系统的一部分。

<!-- TODO: replace with real screenshots
![Screenshot — thumbnail view](docs/images/screenshot-thumbnails.png)
![Screenshot — title list](docs/images/screenshot-titles.png)
-->

## Features

- **Window-level switching** — every window of every regular app, not aggregated by app.
- **Global hotkey** `⌥ Tab` (customizable) and **in-app cycle** `⌥ \`` (customizable).
- **Hold to browse, release to switch** — keep the modifier held, tap the key or use
  arrows / `Tab` to browse, release the modifier to confirm. `Esc` cancels.
- **Three view modes** — live window thumbnails, app icons, or a compact title list.
- **MRU ordering** — most-recently-used first, persisted across launches.
- **Fuzzy search** — type anywhere, match against app name, window title and bundle ID;
  subsequence matching (`vs` → *Visual Studio Code*), app-name weighting, character highlight,
  plus a persistent **search memory** so your abbreviations keep getting smarter.
- **Quick actions on the selected window** —
  `⌘W` close · `⌘M` minimize · `⌘F` toggle fullscreen · `⌘Q` quit app ·
  `⌘H` hide app · `⌘R` reveal in Finder · `⌘,` settings.
- **State badges** — minimized, fullscreen, other-Space windows are marked and still switchable.
- **Multi-display aware** — panel follows the mouse screen; optional per-screen filtering.
- **Thumbnails** — ScreenCaptureKit on macOS 14+, `CGWindowListCreateImage` fallback on
  macOS 13; cached with a 5-second TTL; degrades gracefully to app icons without permission.
- **Native minimal UI** — frosted-glass panel, light & dark appearance, 中文 / English.
- **100% command-line build** — no `.xcodeproj`, no code signing, no private APIs.

## System Requirements

- macOS **13.0** (Ventura) or newer — Apple Silicon & Intel.
- Accessibility permission (required) and Screen Recording permission (optional, thumbnails only).

## Installation

1. Download `SakuraSwitch.dmg` (or `SakuraSwitch.zip`) from the
   [latest release](https://github.com/yueseqaz/sakura-switch/releases).
2. Open the DMG and drag **Sakura Switch** into *Applications*.

### ⚠️ Unsigned app — first launch

Sakura Switch is a community, **unsigned** app (no Apple Developer certificate, no notarization).
Gatekeeper may block the first launch:

- Right-click `Sakura Switch.app` → **Open** → **Open** in the dialog; *or*
- Double-click it once, then go to **System Settings → Privacy & Security**, scroll down and
  click **Open Anyway**.

This is expected for all unsigned open-source apps. You can also build it yourself from source
(instructions below), which many users prefer.

### 🔐 Permissions

| Permission | Required | Why |
|---|---|---|
| **Accessibility** | ✅ required | To enumerate and raise other apps' windows via the Accessibility API. The switcher will not appear until it is granted. |
| **Screen Recording** | optional | Only needed for window thumbnails. Without it you still get app icons. |

> **Note for unsigned apps:** macOS records Accessibility grants by *bundle ID + code signature /
> executable path*. Because this app is unsigned, **recompiling or moving the `.app` may invalidate
> the grant** — if the switcher stops appearing, re-tick *Sakura Switch* under
> **System Settings → Privacy & Security → Accessibility**.
> The same applies after replacing the binary with a different build.
> Sakura Switch re-checks the permission every time it is invoked, so no restart is needed.

## Build from Source

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`), Swift 5.9+.

```bash
git clone https://github.com/yueseqaz/sakura-switch.git
cd sakura-switch
swift build -c release
bash scripts/build-app.sh 1.0.0
open build/SakuraSwitch.app
```

The script assembles `build/SakuraSwitch.app` from the SwiftPM build product — no Xcode project
involved, and the result is not code-signed.

For a distributable artifact:

```bash
bash scripts/package-dmg.sh 1.0.0   # produces build/SakuraSwitch.dmg + .zip
```

## Development & Testing

```bash
swift build          # debug build
swift test           # test suite (core logic only)
```

Tests use Apple's [Swift Testing](https://developer.apple.com/xcode/swift-testing/)
framework (`import Testing`) instead of XCTest — XCTest is unavailable on
Command Line Tools-only machines, and this project is committed to building
with plain `swift build` / `swift test` (no Xcode required).

UI / AX behaviors that cannot be covered by unit tests are tracked in
[`docs/manual-test.md`](docs/manual-test.md).

A debug-only self test renders the switcher panel with synthetic windows,
handy for UI work without an Accessibility grant:

```bash
swift run SakuraSwitch --self-test                 # screenshot + quit
swift run SakuraSwitch --self-test --self-test-search "vs"   # scripted search
```

## Project Layout

```
Sources/SakuraSwitchCore/    # core logic library (permissions, AX, MRU, search, settings…)
Sources/SakuraSwitch/        # executable: AppKit entry, panel & settings UI
Tests/SakuraSwitchCoreTests/ # Swift Testing suite for the core library
scripts/                     # build-app.sh / package-dmg.sh / make-icon.swift
Resources/                   # AppIcon.icns (generated by scripts/make-icon.swift)
docs/                        # manual-test checklist
.github/workflows/           # CI (build.yml) & release (release.yml)
```

> **Note on the UI stack:** the interface is pure AppKit
> (NSVisualEffectView, NSSwitch, NSTabViewController, CGEvent taps) — the
> most native look and behavior, and no dependency on SwiftUI property
> wrapper macros, which keeps the project buildable with Command Line
> Tools alone.

## Contributing

Issues and pull requests are welcome!

1. Fork the repository and create a feature branch.
2. Keep changes compiling with `swift build` and covered by `swift test`.
3. Open a PR against `main`. CI must pass.

Please keep the code style consistent (Swift 5 language mode, no external dependencies in the
core library) and document user-visible changes in `CHANGELOG.md`.

## Known Limitations

- **Unsigned & un-notarized** — triggers Gatekeeper on first launch (see above) and may require
  re-granting Accessibility after rebuilds.
- **Cross-Space switching** is subject to macOS restrictions — windows on other desktops are
  listed and marked, and the system performs the space transition; edge cases may behave
  differently from a signed app.
- Thumbnails require Screen Recording permission; without it, app icons are shown instead.
- No private APIs are used; some deep system behaviors are therefore intentionally not attempted.

## License

[MIT](LICENSE) © 2026 yueseqaz
