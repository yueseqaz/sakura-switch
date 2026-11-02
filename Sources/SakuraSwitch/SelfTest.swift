import AppKit
import SakuraSwitchCore

/// Debug-only self test: `SakuraSwitch.app/Contents/MacOS/SakuraSwitch --self-test`
/// shows the switcher panel with synthetic windows — lets UI work proceed
/// without an Accessibility grant. Compiled out of release builds.
#if DEBUG
@MainActor
enum SelfTest {

    static func isRequested() -> Bool {
        ProcessInfo.processInfo.arguments.contains("--self-test")
    }

    static func run() {
        setbuf(stdout, nil)
        if ProcessInfo.processInfo.arguments.contains("--self-test-live") {
            print("SELFTEST accessibility=\(AccessibilityPermission.isGranted) screenRecording=\(ScreenCapturePermission.isGranted)")
            DispatchQueue.global(qos: .userInitiated).async {
                let windows = WindowEnumerator().enumerate(exclusions: Set(AppSettings.defaultExclusions))
                DispatchQueue.main.async { render(windows: windows) }
            }
        } else {
            render(windows: syntheticWindows())
        }
    }

    private static func render(windows: [WindowModel]) {
        SwitcherController.shared.showForSelfTest(windows)
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--self-test-app"),
           index + 1 < ProcessInfo.processInfo.arguments.count {
            SwitcherController.shared.setSelfTestApplication(ProcessInfo.processInfo.arguments[index + 1])
        }
        if ProcessInfo.processInfo.arguments.contains("--self-test-interactions") {
            SwitcherController.shared.checkSelfTestNavigation()
        }
        if ProcessInfo.processInfo.arguments.contains("--self-test-selection-preview") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                SwitcherController.shared.setSelfTestSelectionPreview(0)
            }
        }

        // Optional scripted search: --self-test-search "vs"
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--self-test-search"),
           index + 1 < ProcessInfo.processInfo.arguments.count {
            let query = ProcessInfo.processInfo.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                SwitcherController.shared.setSelfTestSearch(query)
            }
        }

        // Save a bitmap of the panel content for permission-free UI review.
        // `--self-test-stay` keeps the app alive for interactive checks.
        let stay = ProcessInfo.processInfo.arguments.contains("--self-test-stay")
        let captureDelay: TimeInterval = ProcessInfo.processInfo.arguments.contains("--self-test-live") ? 10 : 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay) {
            if ProcessInfo.processInfo.arguments.contains("--self-test-selection-preview") {
                SwitcherController.shared.saveSelfTestSelectionPreviewSnapshot()
            }
            SwitcherController.shared.saveDebugSnapshot(to: "/tmp/sakura-selftest.png")
            print("SELFTEST mode=\(AppContext.shared.settings.current.appearance.viewMode.rawValue)")
            if !stay {
                NSApp.terminate(nil)
            }
        }
    }

    static func syntheticWindows() -> [WindowModel] {
        let iconTerminal = NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app")
        let iconSafari = NSWorkspace.shared.icon(forFile: "/System/Applications/Safari.app")
        let iconNotes = NSWorkspace.shared.icon(forFile: "/System/Applications/Notes.app")
        let iconCode = NSWorkspace.shared.icon(forFile: "/Applications/Visual Studio Code.app")
        let iconFinder = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")

        var now = Date()
        func stamp() -> Date { now = now.addingTimeInterval(-60); return now }
        let specs: [(String, String, NSImage, Bool, Bool, Bool, String)] = [
            // title, app, icon, minimized, fullscreen, onScreen, bundleID
            ("main.swift — SakuraSwitch", "Visual Studio Code", iconCode, false, false, true, "com.microsoft.VSCode"),
            ("Apple", "Safari", iconSafari, false, false, true, "com.apple.Safari"),
            ("首页 — Macintosh HD", "Finder", iconFinder, false, false, true, "com.apple.finder"),
            ("购物清单", "Notes", iconNotes, true, false, false, "com.apple.Notes"),
            ("终端 — zsh", "Terminal", iconTerminal, false, false, true, "com.apple.Terminal"),
            ("Design Review", "Visual Studio Code", iconCode, false, false, false, "com.microsoft.VSCode"),
            ("Sakura Switch — README.md", "Visual Studio Code", iconCode, false, false, true, "com.microsoft.VSCode"),
        ]

        var models: [WindowModel] = []
        for (index, spec) in specs.enumerated() {
            let (title, app, icon, minimized, fullscreen, onScreen, bundleID) = spec
            models.append(WindowModel(
                windowID: CGWindowID(1000 + index),
                pid: pid_t(100 + index),
                appName: app,
                bundleID: bundleID,
                windowTitle: title,
                appIcon: icon,
                frame: CGRect(x: 100 * index, y: 100,
                              width: [1200, 700, 1800, 900, 1200, 1500, 800][index],
                              height: [800, 1100, 700, 1400, 800, 900, 1200][index]),
                isMinimized: minimized,
                isFullscreen: fullscreen,
                isOnScreen: onScreen,
                screenID: 1,
                lastUsedAt: stamp(),
                axElement: nil,
                isExcluded: false
            ))
        }
        return models
    }
}
#endif
