# Changelog

All notable changes to **Sakura Switch** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-11-02

### Added

- Hotkeys setting for release behavior: switch and close on modifier release,
  or keep the selected window and panel open.
- Selection dwell magnification for window thumbnails, with a much larger,
  higher-resolution capture in a mouse-transparent floating preview that does not
  move the grid or take focus.
- Application icon strip with window counts. Hover an application to browse all its
  windows as thumbnails, click a window to switch, and select All Windows or press
  Escape to return to the full list.
- Thumbnail cards and enlarged previews that fit each window's original aspect
  ratio, including portrait and ultrawide windows.

### Fixed

- Keep the switcher open and cycle windows on repeated Option+Tab; support
  Option+Shift+Tab for reverse navigation and release Option to confirm. Opening
  from the menu no longer creates a modifier-release session.
- Preserve the initial second-window selection and early Tab presses while the
  first window enumeration is loading; defer confirmation until it completes.
- Refuse to package over a running build of the app, including an app launched during
  compilation, to avoid breaking the running process's TCC code identity.
- Read `kCGWindowOwnerPID` from Core Graphics window dictionaries. The incorrect
  key discarded every CG window and replaced real window IDs with synthetic ones,
  preventing ScreenCaptureKit from finding any window to capture.
- Sign and verify the complete app bundle, including Info.plist and its bundle identifier,
  so macOS can validate its permission identity. Allow a persistent signing certificate
  through `CODE_SIGN_IDENTITY` and resolve the current SwiftPM product path when packaging.
- Request Accessibility and Screen Recording access from the permission buttons instead
  of only opening System Settings; refresh permission status when returning to the app
  and while the permissions tab is visible.
- Redraw the switcher after asynchronous window enumeration, retry failed thumbnail
  loads, and share in-flight captures instead of leaving duplicate requests on icons.
- Show a Screen Recording permission action when thumbnails cannot be enabled and
  distinguish unavailable previews from previews that are still loading.
- Apply the release-behavior setting even when Option is released before the
  panel finishes opening. Reset the setting's control with Reset to Defaults.
- Keep a selected window's dwell preview open when the pointer leaves a thumbnail.

### Upgrade notes

- Install one copy in Applications and launch it there. This release signs the
  complete app bundle with an ad-hoc signature; macOS may require granting
  Accessibility and Screen Recording again after updating. See README for recovery.

## [1.0.1] - 2026-11-02

- Published the initial implementation as DMG and ZIP downloads.

## [1.0.0] - 2026-11-02

### Added

- Global window switcher panel invoked with `Option + Tab` (customizable).
- In-app window cycling with `Option + Backtick` (customizable).
- Three view modes: live thumbnails, app icons, compact title list.
- MRU (most-recently-used) ordering persisted across launches.
- Fuzzy subsequence search over app name, window title and bundle ID,
  with abbreviation matching (`vs` → Visual Studio Code) and highlight.
- Search memory: frequently used abbreviations rank their window first, persisted and clearable.
- Hold-modifier-release-to-confirm switching; `Esc` cancels.
- Keyboard navigation (arrows, `Tab` / `Shift+Tab`, digits `1–9`) and mouse hover/click.
- Window quick actions from the switcher: close `⌘W`, minimize `⌘M`,
  toggle fullscreen `⌘F`, quit app `⌘Q`, hide app `⌘H`, reveal in Finder `⌘R`, settings `⌘,`.
- Badges for minimized, fullscreen and other-Space windows; multi-display support
  with panel on the mouse screen and optional screen filtering.
- Window thumbnails via ScreenCaptureKit on macOS 14+, `CGWindowListCreateImage`
  fallback on macOS 13, with a 5-second TTL cache and graceful degradation
  without Screen Recording permission.
- Settings window (General / Hotkeys / Appearance / Window Behavior /
  Exclusions / Search / Permissions / About) with JSON persistence,
  light & dark modes, Chinese and English localization.
- Accessibility permission gating with in-app guidance; Screen Recording
  permission requested only when thumbnails are enabled.
- macOS menu bar item with quick access to the switcher and settings.
- Command-line build scripts producing an unsigned `.app`, `.dmg` and `.zip`
  without Xcode or code signing (`scripts/build-app.sh`, `scripts/package-dmg.sh`).
- GitHub Actions CI (`build.yml`) and unsigned release pipeline (`release.yml`).
- XCTest unit tests for MRU ordering, fuzzy matching, search memory, WCAG
  contrast, exclusion filtering, window dedup and settings persistence.

[Unreleased]: https://github.com/yueseqaz/sakura-switch/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/yueseqaz/sakura-switch/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/yueseqaz/sakura-switch/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/yueseqaz/sakura-switch/releases/tag/v1.0.0
