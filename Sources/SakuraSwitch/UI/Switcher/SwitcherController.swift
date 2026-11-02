import AppKit
import Carbon.HIToolbox
import SakuraSwitchCore

/// Orchestrates the switcher: frosted panel, search field, three view modes,
/// event-tap keyboard handling, selection, confirmation and quick actions.
@MainActor
final class SwitcherController {

    static let shared = SwitcherController()

    private let viewModel: SwitcherViewModel
    private let panel: SwitcherPanel
    private let searchField = SearchField()
    private let titleListView = SwitcherListView()
    private let gridView = SwitcherGridView()
    private let applicationStrip = ApplicationStripView()
    private let scrollView = NSScrollView()
    private var applicationStripHeight: NSLayoutConstraint!
    private var captureNoticeHeight: NSLayoutConstraint!
    private var permissionTimer: Timer?
    private var screenCaptureGranted = ScreenCapturePermission.isGranted
    private lazy var captureNotice = DSButton(L10n.switcherScreenCaptureNeeded, kind: .ghost) { [weak self] in
        self?.hide()
        ScreenCapturePermission.requestAndOpenSystemSettings()
    }

    private let keyboard = KeyboardInterceptor()
    private var clickMonitor: Any?
    private var localMonitors: [Any] = []
    private var usingLocalFallback = false
    private var trigger: KeyCombo?
    private var confirmWhenReady = false
    private lazy var hintPanel = PermissionHintPanel()

    /// The mode currently rendered in the content container.
    private var renderedMode: AppSettings.ViewMode?

    private init() {
        viewModel = SwitcherViewModel(settings: AppContext.shared.settings,
                                      mru: AppContext.shared.mru,
                                      searchMemory: AppContext.shared.searchMemory)
        panel = SwitcherPanel()

        // Hover selects; click confirms (both views).
        titleListView.onHoverIndex = { [weak self] index in self?.hoverSelect(index) }
        titleListView.onConfirmIndex = { [weak self] index in self?.selectExactAndConfirm(index) }
        gridView.onHoverIndex = { [weak self] index in self?.hoverSelect(index) }
        gridView.onConfirmIndex = { [weak self] index in self?.selectExactAndConfirm(index) }
        applicationStrip.onFocusApplication = { [weak self] id in
            guard let self else { return }
            self.searchField.stringValue = ""
            self.viewModel.focusApplication(id)
        }
        viewModel.onChange = { [weak self] in
            guard let self, self.panel.isVisible else { return }
            if self.confirmWhenReady, !self.viewModel.isRefreshing {
                self.confirmSelection()
                return
            }
            self.renderContent()
            self.resizePanel()
        }

        // Search field: text changes filter immediately.
        searchField.onTextChange = { [weak self] text in
            guard let self else { return }
            self.viewModel.searchText = text
        }

        let effect = panel.contentView as? NSVisualEffectView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        searchField.translatesAutoresizingMaskIntoConstraints = false
        effect?.addSubview(searchField)
        applicationStrip.translatesAutoresizingMaskIntoConstraints = false
        effect?.addSubview(applicationStrip)
        effect?.addSubview(captureNotice)
        effect?.addSubview(scrollView)
        applicationStripHeight = applicationStrip.heightAnchor.constraint(equalToConstant: ApplicationStripView.height)
        captureNoticeHeight = captureNotice.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: effect!.topAnchor, constant: DS.space2),
            searchField.leadingAnchor.constraint(equalTo: effect!.leadingAnchor, constant: DS.space2),
            searchField.trailingAnchor.constraint(equalTo: effect!.trailingAnchor, constant: -DS.space2),
            searchField.heightAnchor.constraint(equalToConstant: 30),
            applicationStrip.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: DS.space1),
            applicationStrip.leadingAnchor.constraint(equalTo: effect!.leadingAnchor),
            applicationStrip.trailingAnchor.constraint(equalTo: effect!.trailingAnchor),
            applicationStripHeight,
            captureNotice.topAnchor.constraint(equalTo: applicationStrip.bottomAnchor),
            captureNotice.leadingAnchor.constraint(equalTo: effect!.leadingAnchor, constant: DS.space2),
            captureNotice.trailingAnchor.constraint(equalTo: effect!.trailingAnchor, constant: -DS.space2),
            captureNoticeHeight,
            scrollView.topAnchor.constraint(equalTo: captureNotice.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: effect!.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: effect!.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: effect!.bottomAnchor),
        ])
    }

    // MARK: - Panel lifecycle

    func toggleGlobal() {
        panel.isVisible ? hide() : show(inApp: false)
    }

    func toggleInApp() {
        panel.isVisible ? hide() : show(inApp: true)
    }

    func cycleFromHotkey(inApp: Bool, trigger: KeyCombo) {
        if panel.isVisible {
            self.trigger = trigger
            step(1)
        } else {
            show(inApp: inApp, trigger: trigger)
        }
    }

    func show(inApp: Bool, trigger: KeyCombo? = nil) {
        #if DEBUG
        if SelfTest.isRequested() { return } // self test drives the panel directly
        #endif
        guard AccessibilityPermission.isGranted else {
            Log.switcher.info("Accessibility not granted; showing hint")
            hintPanel.show()
            return
        }
        hintPanel.hide()
        self.trigger = trigger
        confirmWhenReady = false
        applicationStrip.prepareForPresentation()
        gridView.prepareForPresentation()
        gridView.resetThumbnails()
        screenCaptureGranted = ScreenCapturePermission.isGranted

        panel.applyMaterial(AppContext.shared.settings.current.appearance.panelMaterial)
        viewModel.activeScreenID = Self.mouseScreenID()
        viewModel.show(inApp: inApp)
        renderedMode = nil
        renderContent()
        positionPanel()
        installInterceptors()
        focusSearch()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        startPermissionRefresh()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1
        })
        // A quick tap can release the modifier before the panel installs its tap.
        handleModifierState(KeyCombo.carbonModifiers(from: NSEvent.modifierFlags))
    }

    func hide() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        applicationStrip.cancelPendingHover()
        gridView.resetThumbnails()
        panel.alphaValue = 1
        panel.orderOut(nil)
        removeInterceptors()
        trigger = nil
        confirmWhenReady = false
        viewModel.cancel()
        viewModel.searchText = ""
        searchField.stringValue = ""
    }

    private func positionPanel() {
        guard let screen = Self.mouseScreen() else { return }
        let visible = screen.visibleFrame
        panel.setContentSize(Self.panelSize(for: contentSize()))
        let frame = panel.frame
        let x = visible.midX - frame.width / 2
        let y = visible.midY - frame.height / 2 - visible.height * 0.06
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Visible chrome above the scroll area: top margin + field + gap.
    private var searchChrome: CGFloat {
        DS.space2 + 30 + DS.space1 + 4
            + (viewModel.inAppMode ? 0 : ApplicationStripView.height)
            + (currentMode == .thumbnails && !screenCaptureGranted ? 32 : 0)
    }

    /// Panel size from deterministic per-mode metrics.
    private func contentSize() -> NSSize {
        let count = viewModel.hits.count
        switch currentMode {
        case .titles:
            let visibleRows = min(max(count, 1), 12)
            let height = CGFloat(count == 0 ? 60 : visibleRows * 38 + 20)
            return NSSize(width: 560, height: height + searchChrome)
        case .icons:
            let width = SwitcherGridView.width(for: .icons, thumbnailSize: .medium)
            let visible = SwitcherGridView.visibleHeight(for: .icons, thumbnailSize: .medium, itemCount: count)
            return NSSize(width: width, height: visible + searchChrome)
        case .thumbnails:
            let size = AppContext.shared.settings.current.appearance.thumbnailSize
            let width = SwitcherGridView.width(for: .thumbnails, thumbnailSize: size)
            let visible = gridView.mode == .thumbnails
                ? gridView.visibleDocumentHeight
                : SwitcherGridView.visibleHeight(for: .thumbnails, thumbnailSize: size, itemCount: count)
            return NSSize(width: width, height: visible + searchChrome)
        }
    }

    private static func panelSize(for contentSize: NSSize) -> NSSize {
        NSSize(width: contentSize.width, height: contentSize.height)
    }

    static func mouseScreen() -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
    }

    static func mouseScreenID() -> CGDirectDisplayID? {
        guard let screen = mouseScreen(),
              let deviceID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(deviceID.uint32Value)
    }

    // MARK: - Rendering

    private var currentMode: AppSettings.ViewMode {
        let settingsMode = AppContext.shared.settings.current.appearance.viewMode
        // In-app cycling prefers the lightweight list for speed.
        if viewModel.inAppMode { return .titles }
        if viewModel.focusedApplicationID != nil { return .thumbnails }
        return settingsMode
    }

    private func renderContent() {
        let mode = currentMode
        applicationStrip.isHidden = viewModel.inAppMode
        applicationStripHeight.constant = viewModel.inAppMode ? 0 : ApplicationStripView.height
        applicationStrip.update(groups: viewModel.applicationGroups, focusedID: viewModel.focusedApplicationID)
        let needsCapture = mode == .thumbnails && !screenCaptureGranted
        captureNotice.isHidden = !needsCapture
        captureNoticeHeight.constant = needsCapture ? 32 : 0

        if mode == .titles {
            if renderedMode != .titles {
                gridView.removeFromSuperview()
                installDocument(titleListView, documentHeight: documentHeight(for: mode))
                renderedMode = .titles
            }
            titleListView.update(viewModel: viewModel)
        } else {
            if renderedMode != mode {
                titleListView.removeFromSuperview()
                installDocument(gridView, documentHeight: documentHeight(for: mode))
                renderedMode = mode
            }
            gridView.update(viewModel: viewModel,
                            mode: mode == .icons ? .icons : .thumbnails,
                            thumbnailSize: AppContext.shared.settings.current.appearance.thumbnailSize)
            gridView.noteSelection(viewModel.selectedIndex)
            gridView.scheduleSelectionPreview(index: viewModel.selectedIndex)
        }
        updateDocumentFrame()
        revealSelection()
    }

    /// Full scrollable height of the document for the current mode/list.
    private func documentHeight(for mode: AppSettings.ViewMode) -> CGFloat {
        let count = viewModel.hits.count
        switch mode {
        case .titles:
            return count == 0 ? 60 : CGFloat(count) * 38 + 20
        case .icons:
            let rows = CGFloat((count + SwitcherGridView.gridColumns - 1) / SwitcherGridView.gridColumns)
            return count == 0 ? 56
                : SwitcherGridView.gridInset + rows * (96 + SwitcherGridView.gridGap) + SwitcherGridView.gridInset
        case .thumbnails:
            return gridView.mode == .thumbnails ? gridView.documentHeight : {
                let size = AppContext.shared.settings.current.appearance.thumbnailSize
                let rows = CGFloat((count + SwitcherGridView.gridColumns - 1) / SwitcherGridView.gridColumns)
                return count == 0 ? 56
                    : SwitcherGridView.gridInset + rows * (size.thumbnailHeight + 30 + SwitcherGridView.gridGap) + SwitcherGridView.gridInset
            }()
        }
    }

    /// Document views are frame-managed (no auto constraints inside the clip).
    private func installDocument(_ view: NSView, documentHeight: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = true
        view.frame = NSRect(x: 0, y: 0, width: contentSize().width, height: documentHeight)
        scrollView.documentView = view
    }

    private func updateDocumentFrame() {
        guard let document = scrollView.documentView else { return }
        document.frame = NSRect(x: 0, y: 0, width: contentSize().width, height: documentHeight(for: currentMode))
        if currentMode != .titles {
            gridView.layoutSubtreeIfNeeded()
        }
    }

    private func resizePanel() {
        let top = panel.frame.maxY
        panel.setContentSize(Self.panelSize(for: contentSize()))
        // Keep app icons under the pointer when the preview grid changes height.
        panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - panel.frame.height))
    }

    private func startPermissionRefresh() {
        permissionTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.panel.isVisible else { return }
                let granted = ScreenCapturePermission.isGranted
                guard granted != self.screenCaptureGranted else { return }
                self.screenCaptureGranted = granted
                self.gridView.resetThumbnails()
                self.renderContent()
                self.resizePanel()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    /// Keep the selected row/cell inside the visible clip area.
    private func revealSelection() {
        guard scrollView.documentView != nil else { return }
        let clipHeight = scrollView.contentView.bounds.height
        guard clipHeight > 0 else { return }
        let y: CGFloat
        let rowHeight: CGFloat
        switch currentMode {
        case .titles:
            guard viewModel.selectedIndex < viewModel.hits.count else { return }
            y = titleListView.rowY(for: viewModel.selectedIndex)
            rowHeight = 36
        case .icons, .thumbnails:
            guard viewModel.selectedIndex < viewModel.hits.count else { return }
            y = gridView.rowY(for: viewModel.selectedIndex)
            rowHeight = gridView.cardHeight(for: viewModel.selectedIndex)
        }
        let origin = scrollView.contentView.bounds.origin
        var newY = origin.y
        if y < origin.y {
            newY = max(0, y - 6)
        } else if y + rowHeight > origin.y + clipHeight {
            newY = y + rowHeight - clipHeight + 6
        }
        if newY != origin.y {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: max(0, newY)))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    private func focusSearch() {
        // A non-activating panel can take key status without activating the
        // app; printable keys and IME composition flow into the search field.
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    // MARK: - Pointer / selection

    private func hoverSelect(_ index: Int) {
        guard index != viewModel.selectedIndex else { return }
        setSelection(index)
    }

    private func selectExactAndConfirm(_ index: Int) {
        setSelection(index)
        confirmSelection()
    }

    private func setSelection(_ index: Int) {
        guard index >= 0, index < viewModel.hits.count else { return }
        let previous = viewModel.selectedIndex
        viewModel.moveSelection(index - previous)
        refreshSelectionUI(previous: previous)
    }

    private func step(_ delta: Int) {
        applicationStrip.cancelPendingHover()
        gridView.dismissSelectionPreview()
        let previous = viewModel.selectedIndex
        viewModel.moveSelection(delta)
        refreshSelectionUI(previous: previous)
    }

    private func refreshSelectionUI(previous: Int) {
        titleListView.refreshSelection(previous: previous, current: viewModel.selectedIndex)
        gridView.refreshSelectionPublic(previous: previous, current: viewModel.selectedIndex)
        gridView.scheduleSelectionPreview(index: viewModel.selectedIndex)
        revealSelection()
    }

    // MARK: - Confirmation

    private func confirmSelection() {
        if viewModel.isEmpty, viewModel.isRefreshing {
            confirmWhenReady = true
            return
        }
        guard let window = viewModel.confirm() else {
            hide()
            return
        }
        WindowActions.activate(window)
        hide()
    }

    // MARK: - Keyboard

    private func installInterceptors() {
        removeInterceptors()
        keyboard.handler = { [weak self] event in
            guard let self, self.panel.isVisible else { return false }
            return self.handleKeyEvent(event)
        }
        let tapCreated = keyboard.start()
        if !tapCreated {
            // No CGEvent tap (Accessibility missing): local monitors only
            // deliver while the app is active, so activate + take key.
            usingLocalFallback = true
            if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged], handler: { [weak self] event in
                guard let self, self.panel.isVisible else { return event }
                return self.handleKeyEvent(event) ? nil : event
            }) {
                localMonitors.append(monitor)
            }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(searchField)
        }

        // Click-outside dismisses (mouse events still go to other apps).
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            let mouse = NSEvent.mouseLocation
            if !self.panel.frame.contains(mouse) {
                self.hide()
            }
        }
    }

    private func removeInterceptors() {
        keyboard.handler = nil
        keyboard.stop()
        localMonitors.forEach { NSEvent.removeMonitor($0) }
        localMonitors.removeAll()
        usingLocalFallback = false
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard panel.isVisible else { return false }

        if event.type == .flagsChanged {
            return handleFlagsChanged(event)
        }
        guard event.type == .keyDown else { return false }

        let flags = KeyCombo.carbonModifiers(from: event.modifierFlags)

        // While an IME composition is active, everything except ⌘-combos
        // goes to the field so candidates can be picked.
        if flags & KeyCombo.command == 0, isComposing {
            return false
        }

        if let action = SwitcherKeyboard.action(keyCode: event.keyCode, modifiers: flags, trigger: trigger) {
            switch action {
            case .step(let delta): step(delta)
            case .confirm: confirmSelection()
            case .escape:
                if viewModel.searchText.isEmpty, viewModel.focusedApplicationID != nil {
                    viewModel.focusApplication(nil)
                } else if viewModel.searchText.isEmpty {
                    hide()
                } else {
                    clearSearch()
                }
            }
            return true
        }

        // ⌘ quick actions; allow text-editing shortcuts into the field.
        if flags & KeyCombo.command != 0 {
            if let action = Self.quickAction(for: event) {
                performQuickAction(action)
                return true
            }
            if Self.isTextEditingShortcut(event) {
                return false
            }
            return true // swallow other ⌘-combos while the panel is up
        }
        guard flags == 0 || flags == KeyCombo.shift else { return false }

        // Digit jump 1–9 — only while the query is empty, otherwise digits
        // flow into the search field.
        if viewModel.searchText.isEmpty,
           let characters = event.charactersIgnoringModifiers,
           let digit = Int(characters.prefix(1)), digit >= 1, digit <= 9,
           viewModel.selectDigit(digit) {
            renderContent()
            return true
        }

        // Printable characters and editing keys flow into the search field.
        return false
    }

    private var isComposing: Bool {
        (searchField.textField.currentEditor() as? NSTextView)?.hasMarkedText() ?? false
    }

    private func clearSearch() {
        searchField.stringValue = ""
        viewModel.searchText = ""
        renderContent()
        resizePanel()
    }

    /// Hold-modifier-release-to-confirm.
    private func handleFlagsChanged(_ event: NSEvent) -> Bool {
        handleModifierState(KeyCombo.carbonModifiers(from: event.modifierFlags))
        return false
    }

    private func handleModifierState(_ modifiers: UInt32,
                                     behavior: AppSettings.Hotkeys.ReleaseBehavior? = nil) {
        let behavior = behavior ?? AppContext.shared.settings.current.hotkeys.releaseBehavior
        switch SwitcherKeyboard.releaseAction(modifiers: modifiers, trigger: trigger, behavior: behavior) {
        case .none:
            break
        case .keepOpen:
            trigger = nil
            gridView.scheduleSelectionPreview(index: viewModel.selectedIndex)
        case .confirm:
            confirmSelection()
        }
    }

    private static func quickAction(for event: NSEvent) -> QuickAction? {
        switch event.charactersIgnoringModifiers {
        case "w": return .close
        case "m": return .minimize
        case "f": return .toggleFullscreen
        case "q": return .quitApp
        case "h": return .hideApp
        case "r": return .reveal
        case ",": return .settings
        default: return nil
        }
    }

    private static func isTextEditingShortcut(_ event: NSEvent) -> Bool {
        switch event.charactersIgnoringModifiers {
        case "a", "c", "v", "x": return true
        default: return false
        }
    }

    private func performQuickAction(_ action: QuickAction) {
        if action == .settings {
            SettingsWindowController.shared.showWindow()
            hide()
            return
        }
        let keepOpen = viewModel.perform(action)
        renderContent()
        resizePanel()
        if !keepOpen {
            hide()
        }
    }

    // MARK: - Self test

    #if DEBUG
    /// Render the panel's content view into a PNG (layout diagnostics).
    func saveDebugSnapshot(to path: String) {
        guard let contentView = panel.contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        let width = max(1, Int(contentView.bounds.width))
        let height = max(1, Int(contentView.bounds.height))
        guard let rep = contentView.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: width, height: height)) else { return }
        contentView.cacheDisplay(in: NSRect(x: 0, y: 0, width: width, height: height), to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SELFTEST panel=\(Int(panel.frame.width))x\(Int(panel.frame.height)) content=\(width)x\(height) hits=\(viewModel.hits.count) mode=\(currentMode.rawValue) selected=\(viewModel.selectedIndex) thumbnails=\(gridView.loadedThumbnailCount)")
        }
    }

    /// Self test: type into the search field programmatically.
    func setSelfTestSearch(_ text: String) {
        searchField.stringValue = text
        viewModel.searchText = text
        renderContent()
        resizePanel()
    }

    func setSelfTestApplication(_ id: String) {
        viewModel.focusApplication(id)
    }

    func checkSelfTestNavigation() {
        let combo = KeyCombo(keyCode: UInt32(kVK_Tab), modifiers: KeyCombo.option)
        trigger = combo
        let start = viewModel.selectedIndex
        let count = viewModel.hits.count
        precondition(count > 1 && panel.isVisible)
        for offset in 1...(count + 2) {
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.option],
                                        timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                                        characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false,
                                        keyCode: UInt16(kVK_Tab))!
            precondition(handleKeyEvent(event))
            precondition(panel.isVisible && viewModel.selectedIndex == (start + offset) % count)
        }
        let beforeCarbonRepeat = viewModel.selectedIndex
        cycleFromHotkey(inApp: false, trigger: combo)
        precondition(panel.isVisible && viewModel.selectedIndex == (beforeCarbonRepeat + 1) % count)
        let reverse = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.option, .shift],
                                       timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                                       characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false,
                                       keyCode: UInt16(kVK_Tab))!
        precondition(handleKeyEvent(reverse) && viewModel.selectedIndex == beforeCarbonRepeat)
        trigger = nil
        let release = NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: [],
                                       timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                                       characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                                       keyCode: UInt16(kVK_Option))!
        _ = handleKeyEvent(release)
        precondition(panel.isVisible)
        trigger = combo
        let selectedBeforeRelease = viewModel.selectedIndex
        handleModifierState(0, behavior: .keepOpen)
        precondition(panel.isVisible && trigger == nil && viewModel.selectedIndex == selectedBeforeRelease)
        print("SELFTEST navigation=passed forward-wrap reverse carbon-repeat menu-release keep-open-release")
    }

    func setSelfTestSelectionPreview(_ index: Int) {
        setSelection(index)
    }

    func saveSelfTestSelectionPreviewSnapshot() {
        gridView.saveSelectionPreviewSnapshotForSelfTest()
    }

    /// Self test: render the panel with synthetic windows (no AX required).
    func showForSelfTest(_ windows: [WindowModel]) {
        applicationStrip.prepareForPresentation()
        gridView.prepareForPresentation()
        panel.applyMaterial(AppContext.shared.settings.current.appearance.panelMaterial)
        viewModel.loadForSelfTest(windows)
        renderedMode = nil
        renderContent()
        positionPanel()
        let interactive = ProcessInfo.processInfo.arguments.contains("--self-test-stay")
        panel.ignoresMouseEvents = !interactive
        if interactive {
            installInterceptors()
            focusSearch()
        } else {
            panel.orderFrontRegardless()
        }
    }
    #endif
}

/// Search field: inset container + magnifier + borderless text field.
/// Fully custom so light/dark and IME behave exactly per the design tokens.
final class SearchField: NSView {
    var onTextChange: ((String) -> Void)?

    let textField = NSTextField(string: "")
    private let iconView = NSImageView()
    private let container = NSView()

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = DS.radiusControl
        layer?.cornerCurve = .continuous

        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        addSubview(container)

        iconView.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        iconView.contentTintColor = DS.textTertiary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(iconView)

        textField.placeholderString = L10n.switcherSearchPlaceholder
        textField.font = DS.fontBody
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.backgroundColor = .clear
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.target = self
        textField.action = #selector(textSubmitted)
        textField.delegate = self
        addSubview(textField)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DS.space2),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: DS.space1),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DS.space2),
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        refreshColors()
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    var stringValue: String {
        get { textField.stringValue }
        set { textField.stringValue = newValue }
    }

    override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(textField)
        return true
    }

    func clearAndFocus() {
        textField.stringValue = ""
        window?.makeFirstResponder(textField)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    private func refreshColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            container.layer?.backgroundColor = DS.control.cgColor
            self.textField.textColor = DS.textPrimary
            self.iconView.contentTintColor = DS.textTertiary
            self.textField.placeholderString = L10n.switcherSearchPlaceholder
        }
    }

    @objc private func textSubmitted() {
        onTextChange?(textField.stringValue)
    }
}

extension SearchField: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        onTextChange?(textField.stringValue)
    }
}
