import Foundation
import Carbon.HIToolbox

/// All user settings, persisted as JSON in Application Support.
/// The decoder tolerates missing fields so older files stay compatible
/// when new settings are introduced.
public struct AppSettings: Codable, Equatable {

    // MARK: - Enumerations

    public enum ViewMode: String, Codable, CaseIterable, Identifiable {
        case thumbnails
        case icons
        case titles
        public var id: String { rawValue }
    }

    public enum ThemePreference: String, Codable, CaseIterable, Identifiable {
        case system
        case light
        case dark
        public var id: String { rawValue }
    }

    public enum PanelMaterial: String, Codable, CaseIterable, Identifiable {
        /// `NSVisualEffectView.Material.hudWindow` — darker frosted glass.
        case hud
        /// `NSVisualEffectView.Material.popover` — lighter frosted glass.
        case popover
        /// `NSVisualEffectView.Material.underWindowBackground`.
        case underWindow
        public var id: String { rawValue }
    }

    public enum ThumbnailSize: String, Codable, CaseIterable, Identifiable {
        case small
        case medium
        case large
        public var id: String { rawValue }

        /// Card width in points (thumbnail view).
        public var cardWidth: CGFloat {
            switch self {
            case .small: return 168
            case .medium: return 208
            case .large: return 256
            }
        }

        public var thumbnailHeight: CGFloat {
            switch self {
            case .small: return 96
            case .medium: return 120
            case .large: return 148
            }
        }
    }

    public enum AppLanguage: String, Codable, CaseIterable, Identifiable {
        case system
        case zhHans
        case en
        public var id: String { rawValue }
    }

    // MARK: - Sub-groups

    public struct General: Codable, Equatable {
        public var launchAtLogin: Bool
        public var language: AppLanguage

        public init(launchAtLogin: Bool = false, language: AppLanguage = .system) {
            self.launchAtLogin = launchAtLogin
            self.language = language
        }

        private enum CodingKeys: String, CodingKey { case launchAtLogin, language }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
            self.language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        }
    }

    public struct Hotkeys: Codable, Equatable {
        public var globalSwitch: KeyCombo
        public var inAppSwitch: KeyCombo

        public init(globalSwitch: KeyCombo = KeyCombo(keyCode: UInt32(kVK_Tab), modifiers: KeyCombo.option),
                    inAppSwitch: KeyCombo = KeyCombo(keyCode: UInt32(kVK_ANSI_Grave), modifiers: KeyCombo.option)) {
            self.globalSwitch = globalSwitch
            self.inAppSwitch = inAppSwitch
        }

        private enum CodingKeys: String, CodingKey { case globalSwitch, inAppSwitch }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.globalSwitch = try c.decodeIfPresent(KeyCombo.self, forKey: .globalSwitch) ?? Hotkeys().globalSwitch
            self.inAppSwitch = try c.decodeIfPresent(KeyCombo.self, forKey: .inAppSwitch) ?? Hotkeys().inAppSwitch
        }
    }

    public struct Appearance: Codable, Equatable {
        public var viewMode: ViewMode
        public var theme: ThemePreference
        public var panelMaterial: PanelMaterial
        public var thumbnailSize: ThumbnailSize

        public init(viewMode: ViewMode = .thumbnails,
                    theme: ThemePreference = .system,
                    panelMaterial: PanelMaterial = .popover,
                    thumbnailSize: ThumbnailSize = .medium) {
            self.viewMode = viewMode
            self.theme = theme
            self.panelMaterial = panelMaterial
            self.thumbnailSize = thumbnailSize
        }

        private enum CodingKeys: String, CodingKey { case viewMode, theme, panelMaterial, thumbnailSize }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.viewMode = try c.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? .thumbnails
            self.theme = try c.decodeIfPresent(ThemePreference.self, forKey: .theme) ?? .system
            self.panelMaterial = try c.decodeIfPresent(PanelMaterial.self, forKey: .panelMaterial) ?? .popover
            self.thumbnailSize = try c.decodeIfPresent(ThumbnailSize.self, forKey: .thumbnailSize) ?? .medium
        }
    }

    public struct WindowBehavior: Codable, Equatable {
        public var showMinimized: Bool
        public var showFullscreen: Bool
        public var showOtherSpace: Bool
        /// Only list windows on the screen the panel appears on.
        public var filterByActiveScreen: Bool

        public init(showMinimized: Bool = true,
                    showFullscreen: Bool = true,
                    showOtherSpace: Bool = true,
                    filterByActiveScreen: Bool = false) {
            self.showMinimized = showMinimized
            self.showFullscreen = showFullscreen
            self.showOtherSpace = showOtherSpace
            self.filterByActiveScreen = filterByActiveScreen
        }

        private enum CodingKeys: String, CodingKey {
            case showMinimized, showFullscreen, showOtherSpace, filterByActiveScreen
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.showMinimized = try c.decodeIfPresent(Bool.self, forKey: .showMinimized) ?? true
            self.showFullscreen = try c.decodeIfPresent(Bool.self, forKey: .showFullscreen) ?? true
            self.showOtherSpace = try c.decodeIfPresent(Bool.self, forKey: .showOtherSpace) ?? true
            self.filterByActiveScreen = try c.decodeIfPresent(Bool.self, forKey: .filterByActiveScreen) ?? false
        }
    }

    public struct Search: Codable, Equatable {
        public var fuzzyEnabled: Bool
        public var memoryEnabled: Bool

        public init(fuzzyEnabled: Bool = true, memoryEnabled: Bool = true) {
            self.fuzzyEnabled = fuzzyEnabled
            self.memoryEnabled = memoryEnabled
        }

        private enum CodingKeys: String, CodingKey { case fuzzyEnabled, memoryEnabled }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.fuzzyEnabled = try c.decodeIfPresent(Bool.self, forKey: .fuzzyEnabled) ?? true
            self.memoryEnabled = try c.decodeIfPresent(Bool.self, forKey: .memoryEnabled) ?? true
        }
    }

    // MARK: - Fields

    public var general: General
    public var hotkeys: Hotkeys
    public var appearance: Appearance
    public var windowBehavior: WindowBehavior
    public var search: Search
    /// Bundle IDs excluded from the switcher.
    public var excludedBundleIDs: [String]
    public var schemaVersion: Int

    // MARK: - Init

    public init(general: General = General(),
                hotkeys: Hotkeys = Hotkeys(),
                appearance: Appearance = Appearance(),
                windowBehavior: WindowBehavior = WindowBehavior(),
                search: Search = Search(),
                excludedBundleIDs: [String] = AppSettings.defaultExclusions,
                schemaVersion: Int = 1) {
        self.general = general
        self.hotkeys = hotkeys
        self.appearance = appearance
        self.windowBehavior = windowBehavior
        self.search = search
        self.excludedBundleIDs = excludedBundleIDs
        self.schemaVersion = schemaVersion
    }

    /// Apps that never contain switchable windows.
    public static let defaultExclusions: [String] = [
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.dock",
    ]

    // MARK: - Codable with per-field defaults

    private enum CodingKeys: String, CodingKey {
        case general, hotkeys, appearance, windowBehavior, search
        case excludedBundleIDs, schemaVersion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.general = try c.decodeIfPresent(General.self, forKey: .general) ?? General()
        self.hotkeys = try c.decodeIfPresent(Hotkeys.self, forKey: .hotkeys) ?? Hotkeys()
        self.appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? Appearance()
        self.windowBehavior = try c.decodeIfPresent(WindowBehavior.self, forKey: .windowBehavior) ?? WindowBehavior()
        self.search = try c.decodeIfPresent(Search.self, forKey: .search) ?? Search()
        self.excludedBundleIDs = try c.decodeIfPresent([String].self, forKey: .excludedBundleIDs) ?? AppSettings.defaultExclusions
        self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}
