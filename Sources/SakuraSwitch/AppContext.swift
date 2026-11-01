import Foundation
import AppKit
import Combine
import SakuraSwitchCore

/// Composition root: owns the long-lived services of the app.
/// Core types stay independent; everything is wired here.
@MainActor
final class AppContext: ObservableObject {

    static let shared = AppContext()

    let settings: SettingsStore
    let mru: MRUStore
    let searchMemory: SearchMemoryStore
    let hotkeys: HotkeyCoordinator

    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.settings = SettingsStore()
        self.mru = MRUStore()
        self.searchMemory = SearchMemoryStore()
        self.hotkeys = HotkeyCoordinator(settings: settings)

        // Appearance follows the theme preference immediately.
        settings.$settings
            .map { $0.appearance.theme }
            .removeDuplicates()
            .sink { theme in Self.applyAppearance(theme) }
            .store(in: &cancellables)

        Self.applyAppearance(settings.current.appearance.theme)
    }

    static func applyAppearance(_ theme: AppSettings.ThemePreference) {
        switch theme {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
