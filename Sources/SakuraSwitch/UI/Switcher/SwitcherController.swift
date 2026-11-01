import AppKit
import Carbon.HIToolbox
import SakuraSwitchCore

/// Orchestrates the switcher: panel lifecycle, keyboard handling, selection,
/// confirmation and quick actions.
@MainActor
final class SwitcherController {

    static let shared = SwitcherController()

    private let viewModel: SwitcherViewModel
    private let panel: SwitcherPanel
    private let listView = SwitcherListView()
    private let keyboard = KeyboardInterceptor()
    private var clickMonitor: Any?
    private lazy var hintPanel = PermissionHintPanel()

    private init() {
        viewModel = SwitcherViewModel(settings: AppContext.shared.settings,
                                      mru: AppContext.shared.mru,
                                      searchMemory: AppContext.shared.searchMemory)
        panel = SwitcherPanel()

        // Hover selects; click confirms.
        listView.onHoverIndex = { [weak self] index in
            self?.hoverSelect(index)
        }
        listView.onConfirmIndex = { [weak self] index in
            self?.selectExactAndConfirm(index)
        }

        let effect = panel.contentView as? NSVisualEffectView
        effect?.addSubview(listView)
        NSLayoutConstraint.activate([
            listView.leadingAnchor.constraint(equalTo: effect!.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: effect!.trailingAnchor),
            listView.topAnchor.constraint(equalTo: effect!.topAnchor),
            listView.bottomAnchor.constraint(equalTo: effect!.bottomAnchor),
        ])

    }

    // MARK: - Panel lifecycle

    func toggleGlobal() {
        panel.isVisible ? hide() : show(inApp: false)
    }

    func toggleInApp() {
        panel.isVisible ? hide() : show(inApp: true)
    }

    func show(inApp: Bool) {
        #if DEBUG
        if SelfTest.isRequested() { return } // self test drives the panel directly
        #endif
        guard AccessibilityPermission.isGranted else {
            Log.switcher.info("Accessibility not granted; showing hint")
            hintPanel.show()
            return
        }
        hintPanel.hide()

        panel.applyMaterial(AppContext.shared.settings.current.appearance.panelMaterial)
        viewModel.activeScreenID = Self.mouseScreenID()
        viewModel.show(inApp: inApp)
        render()

        positionPanel()
        installInterceptors()
        // Non-activating + non-key: the event tap provides all keyboard input.
        panel.orderFrontRegardless()
    }

    /// When the CGEvent tap is unavailable (no Accessibility yet), fall back
    /// to local monitors — they only deliver while the app is active, so the
    /// panel takes key status in that mode.
    private var usingLocalFallback = false
    private var localMonitors: [Any] = []

    private func installFallbackMonitors() {
        removeFallbackMonitors()
        usingLocalFallback = true
        localMonitors.append(NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            return self.handleKeyEvent(event) ? nil : event
        })
    }

    private func removeFallbackMonitors() {
        localMonitors.forEach { NSEvent.removeMonitor($0) }
        localMonitors.removeAll()
        usingLocalFallback = false
    }

    func hide() {
        panel.orderOut(nil)
        removeInterceptors()
        viewModel.triggerModifiers = 0
    }

    #if DEBUG
    /// Self test: render the panel with synthetic windows (no AX required).
    func showForSelfTest(_ windows: [WindowModel]) {
        panel.applyMaterial(AppContext.shared.settings.current.appearance.panelMaterial)
        viewModel.loadForSelfTest(windows)
        render()
        positionPanel()
        installInterceptors()
        if usingLocalFallback {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }
    #endif

    private func positionPanel() {
        guard let screen = Self.mouseScreen() else { return }
        let visible = screen.visibleFrame
        let size = Self.panelSize(for: listView.intrinsicContentSize)
        panel.setContentSize(size)

        let frame = panel.frame
        let x = visible.midX - frame.width / 2
        let y = visible.midY - frame.height / 2 - visible.height * 0.06
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private static func panelSize(for contentSize: NSSize) -> NSSize {
        let width = max(560, min(720, contentSize.width + 24))
        let height = contentSize.height + 12
        return NSSize(width: width, height: height)
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

    private func render() {
        listView.update(viewModel: viewModel)
        panel.setContentSize(Self.panelSize(for: listView.intrinsicContentSize))
    }

    private func hoverSelect(_ index: Int) {
        let previous = viewModel.selectedIndex
        guard index != previous else { return }
        setSelection(index)
    }

    private func selectExactAndConfirm(_ index: Int) {
        setSelection(index)
        confirmSelection()
    }

    /// Exact index selection regardless of digit limits.
    private func setSelection(_ index: Int) {
        guard index >= 0, index < viewModel.hits.count else { return }
        let previous = viewModel.selectedIndex
        viewModel.moveSelection(index - previous)
        listView.refreshSelection(previous: previous, current: index)
    }

    // MARK: - Confirmation

    private func confirmSelection() {
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
            installFallbackMonitors()
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
        removeFallbackMonitors()
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

        // ⌘-quick actions on the selected window.
        if flags & KeyCombo.command != 0 {
            if let action = Self.quickAction(for: event) {
                performQuickAction(action)
                return true
            }
            return true // swallow other ⌘-combos while the panel is up
        }
        guard flags == 0 || flags == KeyCombo.shift else { return false }

        // Navigation.
        switch event.keyCode {
        case UInt16(kVK_Escape):
            hide()
            return true
        case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
            confirmSelection()
            return true
        case UInt16(kVK_UpArrow), UInt16(kVK_LeftArrow):
            step(-1)
            return true
        case UInt16(kVK_DownArrow), UInt16(kVK_RightArrow):
            step(1)
            return true
        case UInt16(kVK_Tab):
            step(event.modifierFlags.contains(.shift) ? -1 : 1)
            return true
        default:
            break
        }

        // Digit jump 1–9.
        if let characters = event.charactersIgnoringModifiers,
           let digit = Int(characters.prefix(1)), digit >= 1, digit <= 9,
           viewModel.selectDigit(digit) {
            render()
            return true
        }

        // Unhandled keys are swallowed while the panel is visible (search
        // field takes over printable keys in a later milestone).
        return true
    }

    private func step(_ delta: Int) {
        let previous = viewModel.selectedIndex
        viewModel.moveSelection(delta)
        listView.refreshSelection(previous: previous, current: viewModel.selectedIndex)
    }

    /// Hold-modifier-release-to-confirm.
    private func handleFlagsChanged(_ event: NSEvent) -> Bool {
        let trigger = viewModel.triggerModifiers
        guard trigger != 0 else { return true }
        let current = KeyCombo.carbonModifiers(from: event.modifierFlags)
        if current & trigger != trigger {
            confirmSelection()
        }
        return true
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

    private func performQuickAction(_ action: QuickAction) {
        if action == .settings {
            SettingsWindowController.shared.showWindow()
            hide()
            return
        }
        let keepOpen = viewModel.perform(action)
        render()
        if !keepOpen {
            hide()
        }
    }
}
