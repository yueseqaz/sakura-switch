import AppKit
import SakuraSwitchCore

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
            AccessibilityPermission.requestAndOpenSystemSettings()
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
