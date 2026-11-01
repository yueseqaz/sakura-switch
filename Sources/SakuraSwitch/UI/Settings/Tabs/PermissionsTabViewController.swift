import AppKit
import SakuraSwitchCore

/// Permissions: live status for Accessibility and Screen Recording with
/// deep links into System Settings, recheck, and the unsigned-app note.
final class PermissionsTabViewController: SettingsTabViewController {

    init() {
        super.init { Self.buildContent() }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    private static func buildContent() -> [NSView] {
        let accessibilityCard = permissionCard(
            icon: "hand.raised",
            title: L10n.permissionAccessibility,
            purpose: L10n.permissionAccessibilityPurpose,
            granted: AccessibilityPermission.isGranted,
            onOpen: { AccessibilityPermission.openSystemSettings() }
        )

        let screenRecordingCard = permissionCard(
            icon: "camera",
            title: L10n.permissionScreenRecording,
            purpose: L10n.permissionScreenRecordingPurpose,
            granted: ScreenCapturePermission.isGranted,
            onOpen: { ScreenCapturePermission.openSystemSettings() }
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
                                       granted: Bool,
                                       onOpen: @escaping () -> Void) -> NSView {
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
            let nowGranted: Bool
            if title == L10n.permissionAccessibility {
                nowGranted = AccessibilityPermission.isGranted
            } else {
                nowGranted = ScreenCapturePermission.isGranted
            }
            statusIcon.image = NSImage(systemSymbolName: nowGranted ? "checkmark.circle.fill" : "xmark.circle",
                                       accessibilityDescription: nil)
            statusIcon.contentTintColor = nowGranted ? .systemGreen : DS.textTertiary
            statusLabel.stringValue = nowGranted ? L10n.permissionGranted : L10n.permissionDenied
            statusLabel.textColor = nowGranted ? .systemGreen : DS.textSecondary
        }

        return card
    }
}
