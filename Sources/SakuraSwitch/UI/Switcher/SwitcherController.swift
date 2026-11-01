import AppKit
import SakuraSwitchCore

/// Controls the switcher panel lifecycle: show/hide, positioning on the
/// mouse screen, permission gating and the lightweight permission hint.
@MainActor
final class SwitcherController {

    static let shared = SwitcherController()

    private lazy var panel: SwitcherPanel = {
        let panel = SwitcherPanel()
        return panel
    }()

    private lazy var hintPanel: PermissionHintPanel = {
        PermissionHintPanel()
    }()

    /// Non-global mode: cycle only within the frontmost app's windows.
    private(set) var inAppMode = false

    func toggleGlobal() {
        if panel.isVisible {
            hide()
        } else {
            inAppMode = false
            show()
        }
    }

    func toggleInApp() {
        if panel.isVisible {
            hide()
        } else {
            inAppMode = true
            show()
        }
    }

    func show() {
        guard AccessibilityPermission.isGranted else {
            Log.switcher.info("Accessibility not granted; showing hint instead")
            hintPanel.show()
            return
        }
        hintPanel.hide()

        panel.applyMaterial(AppContext.shared.settings.current.appearance.panelMaterial)
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        Log.switcher.debug("Switcher shown (\(self.inAppMode ? "in-app" : "global", privacy: .public))")
    }

    func hide() {
        panel.orderOut(nil)
        hintPanel.hide()
    }

    private func positionPanel() {
        let mouseScreen = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main
        guard let screen = mouseScreen else { return }

        let visible = screen.visibleFrame
        let size = panel.frame.size
        // Center of the mouse screen, slightly below center ("中央偏下").
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2 - visible.height * 0.06
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// Lightweight, non-blocking accessibility hint shown when the hotkey fires
/// without permission. Frosted, dismissible with Esc/Return.
@MainActor
final class PermissionHintPanel {

    private let panel: SwitcherPanel
    private var monitor: Any?

    init() {
        panel = SwitcherPanel()
        panel.setFrame(NSRect(x: 0, y: 0, width: 380, height: 186), display: false)

        let icon = NSImageView(image: NSImage(systemSymbolName: "lock.shield", accessibilityDescription: nil)!)
        icon.contentTintColor = DS.accent
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)

        let title = makeLabel(L10n.switcherPermissionMissingTitle,
                              font: NSFont.systemFont(ofSize: 14, weight: .semibold))

        let header = NSStackView(views: [icon, title])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = DS.space1

        let body = makeLabel(L10n.switcherPermissionMissingBody, font: DS.fontBody, color: DS.textSecondary)
        body.preferredMaxLayoutWidth = 320

        let openButton = DSButton(L10n.switcherOpenSystemSettings, kind: .accent) { [weak self] in
            AccessibilityPermission.openSystemSettings()
            self?.hide()
        }
        let laterButton = DSButton(L10n.switcherCancel) { [weak self] in
            self?.hide()
        }
        let buttons = NSStackView(views: [openButton, laterButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = DS.space1
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let content = FlippedStackView(views: [header, body, buttons])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = DS.space2
        content.edgeInsets = NSEdgeInsets(top: DS.space3, left: DS.space3, bottom: DS.space3, right: DS.space3)
        content.translatesAutoresizingMaskIntoConstraints = false

        (panel.contentView as? NSVisualEffectView)?.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            content.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            content.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
        ])
    }

    func show() {
        // Center on the mouse screen.
        let mouseScreen = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main
        if let screen = mouseScreen {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.midX - panel.frame.width / 2,
                                         y: visible.midY - panel.frame.height / 2))
        }
        panel.makeKeyAndOrderFront(nil)

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 || event.keyCode == 36 { // Esc or Return
                DispatchQueue.main.async { self?.hide() }
                return nil
            }
            return event
        }
    }

    func hide() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        panel.orderOut(nil)
    }
}
