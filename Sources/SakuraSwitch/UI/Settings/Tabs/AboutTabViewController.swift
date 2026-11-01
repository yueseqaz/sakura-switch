import AppKit
import SakuraSwitchCore

/// About: icon, version, links, license and the command-line build note.
final class AboutTabViewController: SettingsTabViewController {

    init() {
        super.init { Self.buildContent() }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    private static func buildContent() -> [NSView] {
        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let name = makeLabel("Sakura Switch", font: NSFont.systemFont(ofSize: 17, weight: .semibold))
        let version = makeLabel("\(L10n.aboutVersion) \(AppInfo.version) (\(AppInfo.build))",
                                font: DS.fontBody, color: DS.textSecondary)
        let copyright = makeLabel(L10n.aboutCopyright, font: DS.fontCaption, color: DS.textTertiary)

        let textStack = NSStackView(views: [name, version, copyright])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = NSStackView(views: [iconView, textStack])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = DS.space2
        headerRow.edgeInsets = NSEdgeInsets(top: DS.space3, left: DS.space3, bottom: DS.space3, right: DS.space3)
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        let linkStack = NSStackView(views: [])
        linkStack.orientation = .vertical
        linkStack.alignment = .leading
        linkStack.spacing = 0
        linkStack.translatesAutoresizingMaskIntoConstraints = false

        let links: [(String, String, String)] = [
            ("safari", L10n.aboutGitHub, AppInfo.githubURL.absoluteString),
            ("doc.text", L10n.aboutLicense, "https://github.com/yueseqaz/sakura-switch/blob/main/LICENSE"),
        ]
        for (index, link) in links.enumerated() {
            if index > 0 {
                let divider = DSForm.divider(leadingInset: DS.space3)
                divider.widthAnchor.constraint(equalToConstant: 572 - DS.space4).isActive = true
                linkStack.addArrangedSubview(divider)
            }
            let icon = NSImageView(image: NSImage(systemSymbolName: link.0, accessibilityDescription: nil)!)
            icon.contentTintColor = DS.textSecondary
            icon.setContentCompressionResistancePriority(.required, for: .horizontal)

            let label = makeLabel(link.1, font: DS.fontBody, color: DS.accent)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let url = URL(string: link.2)!
            let row = NSStackView(views: [icon, label, NSView()])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = DS.space2
            row.edgeInsets = NSEdgeInsets(top: 8, left: DS.space3, bottom: 8, right: DS.space3)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: 572 - DS.space4).isActive = true
            row.arrangedSubviews[2].setContentHuggingPriority(.defaultLow, for: .horizontal)

            let linkView = HoverLinkView(views: [row])
            linkView.onOpen = { NSWorkspace.shared.open(url) }
            linkStack.addArrangedSubview(linkView)
        }

        let card = DSCardView()
        let inner = NSStackView(views: [headerRow, DSForm.divider(), linkStack])
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

        return [
            makeLabel(L10n.tabAbout, font: DS.fontTitle, color: DS.textPrimary),
            card,
            DSForm.note(L10n.aboutBuildNote, tone: .info),
        ]
    }
}

/// Clickable, hover-highlighting row used for links.
final class HoverLinkView: NSStackView {
    var onOpen: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    init(views: [NSView]) {
        super.init(frame: .zero)
        for view in views {
            addArrangedSubview(view)
        }
        orientation = .vertical
        alignment = .leading
        spacing = 0
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        wantsLayer = true
        layer?.backgroundColor = DS.hover.cgColor
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = .clear
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        onOpen?()
    }
}
