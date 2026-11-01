import SwiftUI
import SakuraSwitchCore

/// Entry point. All real work happens in `AppDelegate`; the settings scene
/// is intentionally empty because the app owns its own settings window.
@main
struct SakuraSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
