# Changelog

All notable changes to **Sakura Switch** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/yueseqaz/sakura-switch/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yueseqaz/sakura-switch/releases/tag/v1.0.0
