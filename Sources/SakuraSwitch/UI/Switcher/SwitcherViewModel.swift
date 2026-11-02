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
    private(set) var focusedApplicationID: String?
    private(set) var applicationGroups: [ApplicationWindowGroup] = []
    var onChange: (() -> Void)?
    var searchText = "" {
        didSet { applyFilters(preserveSelection: true) }
    }
    private(set) var inAppMode = false
    private var pendingSelectionIndex: Int?
    private(set) var isRefreshing = false

    var selectedWindow: WindowModel? {
        guard selectedIndex < hits.count else { return nil }
        return hits[selectedIndex].window
    }

    var selectedHit: SearchHit? {
        selectedIndex < hits.count ? hits[selectedIndex] : nil
    }

    var isEmpty: Bool { hits.isEmpty }

    // MARK: - Services

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
        focusedApplicationID = nil
        searchText = ""
        pendingSelectionIndex = 1
        selectedIndex = 0
        applyFilters(preserveSelection: false)
        refreshAsync()
    }

    func cancel() {
        refreshGeneration += 1
        isRefreshing = false
        pendingSelectionIndex = nil
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

    func focusApplication(_ id: String?) {
        guard focusedApplicationID != id else { return }
        focusedApplicationID = id
        pendingSelectionIndex = nil
        selectedIndex = 0
        searchText = ""
    }

    func moveSelection(_ delta: Int) {
        guard !hits.isEmpty else {
            if let pendingSelectionIndex { self.pendingSelectionIndex = pendingSelectionIndex + delta }
            return
        }
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
        switch action {
        case .close: _ = WindowActions.close(window)
        case .minimize: _ = WindowActions.minimize(window)
        case .toggleFullscreen: _ = WindowActions.toggleFullscreen(window)
        case .quitApp: _ = WindowActions.quitApp(window)
        case .hideApp: _ = WindowActions.hideApp(window)
        case .reveal: _ = WindowActions.revealInFinder(window)
        case .settings: break
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
        pendingSelectionIndex = nil
        selectedIndex = min(1, max(0, allWindows.count - 1))
        activeScreenID = SwitcherController.mouseScreenID()
        applyFilters(preserveSelection: false)
    }
    #endif

    // MARK: - Refresh

    /// Background enumeration; the cache shows instantly on show().
    func refreshAsync() {
        isRefreshing = true
        refreshGeneration += 1
        let generation = refreshGeneration
        let exclusions = Set(settings.current.excludedBundleIDs)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let models = WindowEnumerator().enumerate(exclusions: exclusions)
            DispatchQueue.main.async {
                guard generation == self.refreshGeneration else { return }
                self.isRefreshing = false
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

        applicationGroups = ApplicationWindowGroup.group(windows)
        if let focusedApplicationID {
            if let group = applicationGroups.first(where: { $0.id == focusedApplicationID }) {
                windows = group.windows
            } else {
                self.focusedApplicationID = nil
            }
        }

        hits = SearchEngine.search(windows: windows,
                                   query: searchText,
                                   memory: searchMemory.memory,
                                   fuzzyEnabled: settings.search.fuzzyEnabled)

        // Restore selection by key, else clamp.
        if let pendingSelectionIndex, !hits.isEmpty {
            selectedIndex = ((pendingSelectionIndex % hits.count) + hits.count) % hits.count
            self.pendingSelectionIndex = nil
        } else if let selectedKey,
           let index = hits.firstIndex(where: { $0.window.key == selectedKey }) {
            selectedIndex = index
        } else if selectedIndex >= hits.count {
            selectedIndex = max(0, hits.count - 1)
        }
        onChange?()
    }
}
