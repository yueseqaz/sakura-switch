import Testing
import Carbon.HIToolbox
import AppKit
@testable import SakuraSwitchCore

@Suite("Settings model and persistence")
struct SettingsCodableTests {

    @Test("Defaults encode and decode symmetrically")
    func defaultsEncodeAndDecode() throws {
        let settings = AppSettings()
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded == settings)
    }

    @Test("Missing JSON fields fall back to defaults (forward compatibility)")
    func missingFieldsFallBackToDefaults() throws {
        let json = #"{"general":{"language":"zhHans"}}"#
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(decoded.general.language == .zhHans)
        #expect(decoded.hotkeys.globalSwitch.keyCode == UInt32(kVK_Tab))
        #expect(decoded.hotkeys.globalSwitch.modifiers == KeyCombo.option)
        #expect(decoded.windowBehavior == AppSettings.WindowBehavior())
        #expect(decoded.excludedBundleIDs == AppSettings.defaultExclusions)
    }

    @Test("Default hotkeys are ⌥Tab and ⌥`")
    func defaultHotkeys() {
        let defaults = AppSettings.Hotkeys()
        #expect(defaults.globalSwitch.keyCode == UInt32(kVK_Tab))
        #expect(defaults.globalSwitch.modifiers == KeyCombo.option)
        #expect(defaults.inAppSwitch.keyCode == UInt32(kVK_ANSI_Grave))
        #expect(defaults.inAppSwitch.modifiers == KeyCombo.option)
        #expect(defaults.releaseBehavior == .switchAndClose)
    }

    @Test("Release behavior persists and old settings default to closing")
    func releaseBehaviorRoundTrip() throws {
        let settings = AppSettings(hotkeys: AppSettings.Hotkeys(releaseBehavior: .keepOpen))
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.hotkeys.releaseBehavior == .keepOpen)

        let oldData = Data("{\"hotkeys\":{}}".utf8)
        let old = try JSONDecoder().decode(AppSettings.self, from: oldData)
        #expect(old.hotkeys.releaseBehavior == .switchAndClose)
    }

    @Test("KeyCombo display strings")
    func keyComboDisplay() {
        let combo = KeyCombo(keyCode: UInt32(kVK_Tab), modifiers: KeyCombo.option)
        #expect(combo.displayString == "⌥Tab")
        let shiftCmd = KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: KeyCombo.shift | KeyCombo.command)
        #expect(shiftCmd.displayString == "⇧⌘A")
    }

    @Test("NSEvent modifier flags convert to Carbon masks")
    func modifierConversionFromNSEvent() {
        #expect(KeyCombo.carbonModifiers(from: [.option]) == KeyCombo.option)
        #expect(KeyCombo.carbonModifiers(from: [.command, .shift]) == KeyCombo.command | KeyCombo.shift)
        #expect(KeyCombo.carbonModifiers(from: []) == 0)
    }

    @Test("Thumbnail size metrics")
    func thumbnailSizeMetrics() {
        #expect(AppSettings.ThumbnailSize.small.cardWidth == 168)
        #expect(AppSettings.ThumbnailSize.medium.cardWidth == 208)
        #expect(AppSettings.ThumbnailSize.large.cardWidth == 256)
    }

    @Test("JSONFileStore round trip")
    func jsonFileStoreRoundTrip() {
        let file = "test-store-\(UUID().uuidString).json"
        let settings = AppSettings(appearance: AppSettings.Appearance(viewMode: .titles, theme: .dark))
        let saved = JSONFileStore.save(settings, fileName: file)
        #expect(saved)
        let loaded = JSONFileStore.load(AppSettings.self, fileName: file)
        #expect(loaded == settings)
        try? FileManager.default.removeItem(at: JSONFileStore.url(forFile: file))
    }

    @Test("L10n switches between Chinese and English")
    func l10nSwitching() {
        L10n.language = .en
        #expect(L10n.menuSettings == "Settings…")
        L10n.language = .zhHans
        #expect(L10n.menuSettings == "设置…")
        L10n.language = .system
    }
}
