import AppKit
import SakuraSwitchCore

/// Entry point. AppKit `@main` (the SwiftUI `Settings` scene spawned a
/// stray empty window for LSUIElement apps; all UI is AppKit-native).
/// All real work happens in `AppDelegate`.
@main
struct SakuraSwitchApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory) // menu bar app, no Dock icon
        application.run()
    }
}
