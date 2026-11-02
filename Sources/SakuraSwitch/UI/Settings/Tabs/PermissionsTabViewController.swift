import AppKit
import SakuraSwitchCore

/// Permissions: live status for Accessibility and Screen Recording with
/// deep links into System Settings, recheck, and the unsigned-app note.
final class PermissionsTabViewController: SettingsTabViewController {

    private var refreshTimer: Timer?
    private var lastAccessibility: Bool?
    private var lastScreenCapture: Bool?

    init() {
        super.init { Self.buildContent() }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshPermissions()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPermissions),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)
        // Settings can remain visible while the user changes a system toggle.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermissions()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        refreshTimer?.invalidate()
        refreshTimer = nil
        NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func refreshPermissions() {
        let accessibility = AccessibilityPermission.isGranted
        let screenCapture = ScreenCapturePermission.isGranted
        guard accessibility != lastAccessibility || screenCapture != lastScreenCapture else { return }
        lastAccessibility = accessibility
        lastScreenCapture = screenCapture
        Log.permissions.info("Permission status: accessibility=\(accessibility), screenRecording=\(screenCapture)")
        rebuild()
    }

    deinit {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private static func buildContent() -> [NSView] {
        let accessibilityCard = permissionCard(
            icon: "hand.raised",
            title: L10n.permissionAccessibility,
            purpose: L10n.permissionAccessibilityPurpose,
            isGranted: { AccessibilityPermission.isGranted },
            onOpen: { AccessibilityPermission.requestAndOpenSystemSettings() }
        )

        let screenRecordingCard = permissionCard(
            icon: "camera",
            title: L10n.permissionScreenRecording,
            purpose: L10n.permissionScreenRecordingPurpose,
            isGranted: { ScreenCapturePermission.isGranted },
            onOpen: { ScreenCapturePermission.requestAndOpenSystemSettings() }
        )

        return [
            makeLabel(L10n.tabPermissions, font: DS.fontTitle, color: DS.textPrimary),
            accessibilityCard,
            screenRecordingCard,
            DSForm.note(L10n.permissionUnsignedNote, tone: .warning),
        ]
    }

    private static func permissionCard(icon: String,
                                       title: String,
                                       purpose: String,
                                       isGranted: @escaping () -> Bool,
                                       onOpen: @escaping () -> Void) -> NSView {
        let granted = isGranted()
        let iconView = NSImageView(image: NSImage(systemSymbolName: icon, accessibilityDescription: title)!)
        iconView.contentTintColor = DS.textSecondary
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let titleLabel = makeLabel(title, font: DS.fontBodyMedium, color: DS.textPrimary)

        // Status: icon + text — visible without hover, not color-only.
        let statusIcon = NSImageView(image: NSImage(systemSymbolName: granted ? "checkmark.circle.fill" : "xmark.circle",
                                                    accessibilityDescription: nil)!)
        statusIcon.contentTintColor = granted ? .systemGreen : DS.textTertiary
        statusIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        let statusLabel = makeLabel(granted ? L10n.permissionGranted : L10n.permissionDenied,
                                    font: DS.fontCaptionMedium,
                                    color: granted ? .systemGreen : DS.textSecondary)
        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let statusStack = NSStackView(views: [statusIcon, statusLabel])
        statusStack.orientation = .horizontal
        statusStack.alignment = .centerY
        statusStack.spacing = 5

        let topRow = NSStackView(views: [iconView, titleLabel, statusStack])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = DS.space2
        topRow.edgeInsets = NSEdgeInsets(top: 11, left: DS.space3, bottom: 4, right: DS.space3)
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let purposeLabel = makeLabel(purpose, font: DS.fontCaption, color: DS.textSecondary)
        purposeLabel.preferredMaxLayoutWidth = 500
        let purposeInset = NSStackView(views: [purposeLabel])
        purposeInset.edgeInsets = NSEdgeInsets(top: 0, left: DS.space3 + 22 + DS.space2, bottom: 0, right: DS.space3)
        purposeInset.translatesAutoresizingMaskIntoConstraints = false

        let recheckButton = DSButton(L10n.permissionRecheck, kind: .ghost, action: { })
        let openButton = DSButton(L10n.permissionOpenSettings, action: onOpen)

        let buttonsRow = NSStackView(views: [recheckButton, openButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .centerY
        buttonsRow.spacing = DS.space1
        buttonsRow.edgeInsets = NSEdgeInsets(top: 8, left: DS.space3 + 22 + DS.space2, bottom: 11, right: DS.space3)
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false

        let card = DSCardView()
        let inner = NSStackView(views: [topRow, purposeInset, buttonsRow])
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        ])

        // Recheck: re-evaluate and update the status controls in place.
        recheckButton.actionHandler = {
            let nowGranted = isGranted()
            statusIcon.image = NSImage(systemSymbolName: nowGranted ? "checkmark.circle.fill" : "xmark.circle",
                                       accessibilityDescription: nil)
            statusIcon.contentTintColor = nowGranted ? .systemGreen : DS.textTertiary
            statusLabel.stringValue = nowGranted ? L10n.permissionGranted : L10n.permissionDenied
            statusLabel.textColor = nowGranted ? .systemGreen : DS.textSecondary
        }

        return card
    }
}
