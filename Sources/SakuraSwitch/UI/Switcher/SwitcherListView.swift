import AppKit
import SakuraSwitchCore

/// Compact title-list renderer for the switcher (view mode: titles).
/// Rows: app icon + window title + app name; hover selects, click confirms.
final class SwitcherListView: NSView {

    var onConfirmIndex: ((Int) -> Void)?
    var onHoverIndex: ((Int) -> Void)?

    private var rowViews: [NSView] = []
    private let contentStack = FlippedStackView()
    private var hoverTracking: [NSTrackingArea] = []
    private var lastRenderedSignature: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 2
        contentStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    // MARK: - Rendering

    func update(viewModel: SwitcherViewModel) {
        // Avoid re-rendering identical content (hot refreshes are frequent).
        let signature = "\(viewModel.hits.count)-\(viewModel.selectedIndex)-\(viewModel.searchText)-\(viewModel.selectedHit?.titleMatch?.score ?? 0)"
        if signature == lastRenderedSignature { return }
        lastRenderedSignature = signature

        rowViews.forEach { $0.removeFromSuperview() }
        rowViews.removeAll()
        hoverTracking.removeAll()

        if viewModel.isEmpty {
            let empty = makeRow(title: L10n.switcherEmpty,
                                appName: "",
                                icon: nil,
                                selected: false,
                                badges: [],
                                index: -1)
            contentStack.addArrangedSubview(empty)
            empty.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -20).isActive = true
            rowViews.append(empty)
            invalidateIntrinsicContentSize()
            return
        }

        for (index, hit) in viewModel.hits.enumerated() {
            let row = makeRow(title: hit.window.windowTitle.isEmpty ? hit.window.appName : hit.window.windowTitle,
                              appName: hit.window.appName,
                              icon: hit.window.appIcon,
                              selected: index == viewModel.selectedIndex,
                              badges: badges(for: hit.window),
                              index: index)
            contentStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -20).isActive = true
            rowViews.append(row)
        }
        invalidateIntrinsicContentSize()
    }

    private func badges(for window: WindowModel) -> [BadgeKind] {
        var badges: [BadgeKind] = []
        if window.isMinimized { badges.append(.minimized) }
        if window.isFullscreen { badges.append(.fullscreen) }
        if !window.isOnScreen && !window.isMinimized { badges.append(.otherSpace) }
        return badges
    }

    // MARK: - Row construction

    enum BadgeKind {
        case minimized, fullscreen, otherSpace

        var symbol: String {
            switch self {
            case .minimized: return "minus.circle"
            case .fullscreen: return "arrow.up.left.and.arrow.down.right"
            case .otherSpace: return "square.on.square"
            }
        }

        var label: String {
            switch self {
            case .minimized: return L10n.badgeMinimized
            case .fullscreen: return L10n.badgeFullscreen
            case .otherSpace: return L10n.badgeOtherSpace
            }
        }
    }

    private func makeRow(title: String,
                         appName: String,
                         icon: NSImage?,
                         selected: Bool,
                         badges: [BadgeKind],
                         index: Int) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = DS.radiusControl
        row.layer?.cornerCurve = .continuous
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = icon ?? NSApp.applicationIconImage
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
        ])

        let titleLabel = makeLabel(title, font: DS.fontBody, color: DS.textPrimary)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let appLabel = makeLabel(appName, font: DS.fontCaption, color: DS.textSecondary)
        appLabel.lineBreakMode = .byTruncatingTail
        appLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let badgeStack = NSStackView()
        badgeStack.orientation = .horizontal
        badgeStack.spacing = 4
        badgeStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        for badge in badges {
            let imageView = NSImageView(image: NSImage(systemSymbolName: badge.symbol, accessibilityDescription: badge.label)!)
            imageView.contentTintColor = DS.textTertiary
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 12),
                imageView.heightAnchor.constraint(equalToConstant: 12),
            ])
            badgeStack.addArrangedSubview(imageView)
        }

        let rowContent = NSStackView(views: [iconView, titleLabel, badgeStack, appLabel])
        rowContent.orientation = .horizontal
        rowContent.alignment = .centerY
        rowContent.distribution = .fill  // title stretches, app name hugs trailing
        rowContent.spacing = DS.space1
        rowContent.edgeInsets = NSEdgeInsets(top: 7, left: DS.space2, bottom: 7, right: DS.space2)
        rowContent.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowContent)
        NSLayoutConstraint.activate([
            rowContent.topAnchor.constraint(equalTo: row.topAnchor),
            rowContent.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            rowContent.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            rowContent.trailingAnchor.constraint(equalTo: row.trailingAnchor),
        ])

        // Trailing app name keeps a stable width for a calm, aligned look.
        appLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 150).isActive = true
        appLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        // Title stretches into the remaining space.
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        applyRowBackground(row, selected: selected)

        if index >= 0 {
            let area = NSTrackingArea(rect: .zero,
                                      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                      owner: self,
                                      userInfo: ["index": index])
            row.addTrackingArea(area)
            hoverTracking.append(area)

            let click = NSClickGestureRecognizer(target: self, action: #selector(rowClicked(_:)))
            row.addGestureRecognizer(click)
            row.identifier = NSUserInterfaceItemIdentifier(String(index))
        }

        return row
    }

    private func applyRowBackground(_ row: NSView, selected: Bool) {
        row.effectiveAppearance.performAsCurrentDrawingAppearance {
            row.layer?.backgroundColor = (selected ? DS.selection : NSColor.clear).cgColor
        }
    }

    @objc private func rowClicked(_ gesture: NSClickGestureRecognizer) {
        guard let identifier = gesture.view?.identifier,
              let index = Int(identifier.rawValue) else { return }
        onConfirmIndex?(index)
    }

    // MARK: - Hover

    override func mouseEntered(with event: NSEvent) {
        guard let index = event.trackingArea?.userInfo?["index"] as? Int else { return }
        onHoverIndex?(index)
    }

    /// Re-tint a single row after selection changes (cheap partial update).
    func refreshSelection(previous: Int, current: Int) {
        if previous < rowViews.count, previous >= 0 {
            applyRowBackground(rowViews[previous], selected: false)
        }
        if current < rowViews.count, current >= 0 {
            applyRowBackground(rowViews[current], selected: true)
        }
    }

    override var intrinsicContentSize: NSSize {
        let count = rowViews.count
        let height = CGFloat(count) * 36 + 20
        return NSSize(width: 560, height: min(height, 460))
    }
}
