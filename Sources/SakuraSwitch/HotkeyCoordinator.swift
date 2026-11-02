import Foundation
import Combine
import SakuraSwitchCore

/// Registers the two global hotkeys and publishes registration status
/// (surfaced in Settings → Hotkeys). Re-registers on settings changes.
@MainActor
final class HotkeyCoordinator: ObservableObject {

    static let globalID = "global-switch"
    static let inAppID = "in-app-switch"

    @Published private(set) var failedIDs: Set<String> = []

    private var cancellable: AnyCancellable?
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings

        HotkeyCenter.shared.onKeyDown = { [weak self] id in
            self?.handleHotkey(id)
        }

        cancellable = settings.$settings
            .map { $0.hotkeys }
            .removeDuplicates { $0.globalSwitch == $1.globalSwitch && $0.inAppSwitch == $1.inAppSwitch }
            .dropFirst()
            .sink { [weak self] _ in self?.reregisterAll() }

        reregisterAll()
    }

    func reregisterAll() {
        let hotkeys = settings.current.hotkeys
        var failed = Set<String>()

        if !HotkeyCenter.shared.register(id: Self.globalID, combo: hotkeys.globalSwitch) {
            failed.insert(Self.globalID)
        }
        if !HotkeyCenter.shared.register(id: Self.inAppID, combo: hotkeys.inAppSwitch) {
            failed.insert(Self.inAppID)
        }

        if failed != failedIDs {
            failedIDs = failed
        }
        if !failed.isEmpty {
            Log.hotkey.error("Hotkey registration failed for \(failed.joined(separator: ","), privacy: .public)")
        }
    }

    func combo(for id: String) -> KeyCombo? {
        HotkeyCenter.shared.combo(for: id)
    }

    func isFailed(_ id: String) -> Bool {
        failedIDs.contains(id)
    }

    private func handleHotkey(_ id: String) {
        switch id {
        case Self.globalID:
            SwitcherController.shared.cycleFromHotkey(inApp: false, trigger: settings.current.hotkeys.globalSwitch)
        case Self.inAppID:
            SwitcherController.shared.cycleFromHotkey(inApp: true, trigger: settings.current.hotkeys.inAppSwitch)
        default:
            break
        }
    }
}
