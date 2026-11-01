import Foundation

/// File names used by Sakura Switch inside Application Support.
public enum SakuraFiles {
    public static let settings = "settings.json"
    public static let mru = "mru.json"
    public static let searchMemory = "search-memory.json"
}

/// Main-actor observable store around `AppSettings`.
/// Persists on every change; changes take effect immediately because
/// the rest of the app observes this object.
@MainActor
public final class SettingsStore: ObservableObject {

    @Published public private(set) var settings: AppSettings

    private let saveFile: String

    public init(file: String = SakuraFiles.settings, initial: AppSettings? = nil) {
        self.saveFile = file
        let loaded = initial ?? JSONFileStore.load(AppSettings.self, fileName: file) ?? AppSettings()
        self.settings = loaded
        L10n.language = loaded.general.language
    }

    // MARK: - Mutation

    public func update(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
        L10n.language = copy.general.language
        persist(copy)
    }

    private func persist(_ value: AppSettings) {
        JSONFileStore.save(value, fileName: saveFile)
    }

    // MARK: - Convenience accessors

    public var current: AppSettings { settings }

    public func resetHotkeysToDefaults() {
        update { $0.hotkeys = AppSettings.Hotkeys() }
    }

    public func clearSearchMemory() {
        SearchMemoryStore.shared.clear()
    }
}
