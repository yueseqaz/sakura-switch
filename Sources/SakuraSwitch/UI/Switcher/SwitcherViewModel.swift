import AppKit
import Combine
import SakuraSwitchCore

/// Quick window operations available from the switcher.
enum QuickAction {
    case close, minimize, toggleFullscreen, quitApp, hideApp, reveal, settings
}

/// State machine of the switcher panel. All main-actor.
@MainActor
final class SwitcherViewModel {

    // MARK: - State

    private(set) var allWindows: [WindowModel] = []
    private(set) var hits: [SearchHit] = []
    private(set) var selectedIndex = 0
    var searchText = "" {
        didSet { applyFilters(preserveSelection: true) }
    }
    private(set) var inAppMode = false
    /// Carbon modifier mask of the hotkey that opened the panel (for
    /// release-to-confirm). 0 when opened from the menu.
    var triggerModifiers: UInt32 = 0

    var selectedWindow: WindowModel? {
        guard selectedIndex < hits.count else { return nil }
        return hits[selectedIndex].window
    }

    var selectedHit: SearchHit? {
        selectedIndex < hits.count ? hits[selectedIndex] : nil
    }

    var isEmpty: Bool { hits.isEmpty }

    // MARK: - Services

    private let enumerator = WindowEnumerator()
    private let settings: SettingsStore
    private let mru: MRUStore
    private let searchMemory: SearchMemoryStore
    private var refreshGeneration = 0

    init(settings: SettingsStore, mru: MRUStore, searchMemory: SearchMemoryStore) {
        self.settings = settings
        self.mru = mru
        self.searchMemory = searchMemory
    }

    // MARK: - Lifecycle

    /// Panel opened. Selects the second MRU entry (classic cmd-tab feel).
    func show(inApp: Bool) {
        inAppMode = inApp
        searchText = ""
        triggerModifiers = hotkeyTriggerModifiers(inApp: inApp)
        selectedIndex = min(1, max(0, allWindows.count - 1))
        applyFilters(preserveSelection: false)
        refreshAsync()
    }

    private func hotkeyTriggerModifiers(inApp: Bool) -> UInt32 {
        let combo = inApp ? settings.current.hotkeys.inAppSwitch : settings.current.hotkeys.globalSwitch
        return combo.modifiers
    }

    func cancel() {
        // Nothing to persist; controller hides the panel.
    }

    /// Confirm the current selection. Returns the window to activate
    /// (nil when the list is empty).
    func confirm() -> WindowModel? {
        guard let hit = selectedHit else { return nil }
        let window = hit.window
        mru.markUsed(window)
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty,
           settings.current.search.memoryEnabled {
            searchMemory.record(query: searchText, windowKey: window.key)
        }
        return window
    }

    // MARK: - Navigation

    func moveSelection(_ delta: Int) {
        guard !hits.isEmpty else { return }
        let count = hits.count
        selectedIndex = ((selectedIndex + delta) % count + count) % count
    }

    /// Digit 1–9 jump-select. Returns false when out of range.
    func selectDigit(_ digit: Int) -> Bool {
        guard (1...9).contains(digit), digit <= hits.count else { return false }
        selectedIndex = digit - 1
        return true
    }

    // MARK: - Quick actions

    /// Returns true when the panel should refresh (window still exists).
    func perform(_ action: QuickAction) -> Bool {
        guard let window = selectedWindow else { return false }
        let result: Bool
        switch action {
        case .close: result = WindowActions.close(window)
        case .minimize: result = WindowActions.minimize(window)
        case .toggleFullscreen: result = WindowActions.toggleFullscreen(window)
        case .quitApp: result = WindowActions.quitApp(window)
        case .hideApp: result = WindowActions.hideApp(window)
        case .reveal: result = WindowActions.revealInFinder(window)
        case .settings: result = true
        }
        // Close/quit remove the window; others keep the panel open and refresh.
        if action == .close || action == .quitApp {
            mru.list.removeDeadKeys(valid: Set(allWindows.map { $0.key }).subtracting([window.key]))
            refreshAsync()
            return false
        }
        refreshAsync()
        return true
    }

    #if DEBUG
    /// Self test: seed the cache with synthetic windows.
    func loadForSelfTest(_ windows: [WindowModel]) {
        allWindows = windows
        inAppMode = false
        searchText = ""
        triggerModifiers = 0
        selectedIndex = min(1, max(0, allWindows.count - 1))
        activeScreenID = SwitcherController.mouseScreenID()
        applyFilters(preserveSelection: false)
    }
    #endif

    // MARK: - Refresh

    /// Background enumeration; the cache shows instantly on show().
    func refreshAsync() {
        refreshGeneration += 1
        let generation = refreshGeneration
        let exclusions = Set(settings.current.excludedBundleIDs)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let models = self.enumerator.enumerate(exclusions: exclusions)
            DispatchQueue.main.async {
                guard generation == self.refreshGeneration else { return }
                self.merge(models: models)
            }
        }
    }

    /// Merge fresh enumeration into the cache, keeping MRU order and
    /// selection stable.
    private func merge(models: [WindowModel]) {
        var models = models
        mru.restore(into: &models)
        searchMemory.prune(validKeys: Set(models.map { $0.key }))
        allWindows = mru.ordered(models)
        applyFilters(preserveSelection: true)
    }

    // MARK: - Filtering

    /// The screen the panel appears on (for per-screen filtering).
    var activeScreenID: CGDirectDisplayID?

    private func applyFilters(preserveSelection: Bool) {
        let selectedKey = preserveSelection ? selectedWindow?.key : nil
        let settings = settings.current
        let behavior = settings.windowBehavior

        var windows = allWindows

        // In-app mode: only windows of the frontmost app.
        if inAppMode {
            let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            windows = windows.filter { $0.pid == frontPID }
        }

        // Behavior switches.
        if !behavior.showMinimized {
            windows = windows.filter { !$0.isMinimized }
        }
        if !behavior.showFullscreen {
            windows = windows.filter { !$0.isFullscreen }
        }
        if !behavior.showOtherSpace {
            windows = windows.filter { $0.isOnScreen || $0.isMinimized }
        }
        // Per-screen filter.
        if behavior.filterByActiveScreen, let activeID = activeScreenID {
            windows = windows.filter { $0.screenID == activeID }
        }

        hits = SearchEngine.search(windows: windows,
                                   query: searchText,
                                   memory: searchMemory.memory,
                                   fuzzyEnabled: settings.search.fuzzyEnabled)

        // Restore selection by key, else clamp.
        if let selectedKey,
           let index = hits.firstIndex(where: { $0.window.key == selectedKey }) {
            selectedIndex = index
        } else if selectedIndex >= hits.count {
            selectedIndex = max(0, hits.count - 1)
        }
    }
}
