import AppKit
import SakuraSwitchCore

/// Grid renderer for icon and thumbnail view modes. Flipped (top-down).
/// Metrics are computed from an explicit target width — never from the
/// mid-layout bounds — so panel sizing is deterministic.
/// Thumbnails load asynchronously through `ThumbnailProvider`; stale tasks
/// are cancelled when cells are replaced or the list refreshes.
final class SwitcherGridView: NSView {

    enum Mode {
        case icons
        case thumbnails
    }

    var onConfirmIndex: ((Int) -> Void)?
    var onHoverIndex: ((Int) -> Void)?

    private(set) var mode: Mode = .icons
    private(set) var thumbnailSize: AppSettings.ThumbnailSize = .medium

    private var cells: [NSView] = []
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var currentSelection = -1
    private var lastSignature: String = ""
    private var hoveredCell: NSView?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    // MARK: - Metrics (pure, deterministic)

    static let gridGap: CGFloat = 10
    static let gridInset: CGFloat = 12
    static let gridColumns = 4

    var cardWidth: CGFloat {
        mode == .icons ? 108 : thumbnailSize.cardWidth
    }

    var cardHeight: CGFloat {
        mode == .icons ? 96 : thumbnailSize.thumbnailHeight + 30
    }

    /// Width needed to show `gridColumns` columns.
    var preferredWidth: CGFloat {
        Self.width(for: mode, thumbnailSize: thumbnailSize)
    }

    static func width(for mode: Mode, thumbnailSize: AppSettings.ThumbnailSize) -> CGFloat {
        let card: CGFloat = mode == .icons ? 108 : thumbnailSize.cardWidth
        return CGFloat(gridColumns) * card + CGFloat(gridColumns - 1) * gridGap + 2 * gridInset
    }

    func rowHeight() -> CGFloat { cardHeight + Self.gridGap }

    /// y offset (flipped coordinates) of the row containing `index`.
    func rowY(for index: Int) -> CGFloat {
        let row = index / Self.gridColumns
        return Self.gridInset + CGFloat(row) * rowHeight()
    }

    static func visibleHeight(for mode: Mode, thumbnailSize: AppSettings.ThumbnailSize, itemCount: Int) -> CGFloat {
        let card: CGFloat = mode == .icons ? 96 : thumbnailSize.thumbnailHeight + 30
        let maxRows: CGFloat = mode == .icons ? 3 : 2
        if itemCount == 0 { return 56 }
        let rows = CGFloat((itemCount + gridColumns - 1) / gridColumns)
        return min(rows, maxRows) * (card + gridGap) - gridGap + 2 * gridInset
    }

    // MARK: - Rendering

    func update(viewModel: SwitcherViewModel,
                mode newMode: Mode,
                thumbnailSize newSize: AppSettings.ThumbnailSize) {
        mode = newMode
        thumbnailSize = newSize

        let signature = viewModel.hits.map { $0.window.key }.joined(separator: ",")
            + "|\(mode == .icons ? "i" : "t")|\(thumbnailSize.rawValue)"
        if signature == lastSignature {
            refreshAllSelections(selected: viewModel.selectedIndex)
            return
        }
        lastSignature = signature

        cancelAllTasks()
        cells.forEach { $0.removeFromSuperview() }
        cells.removeAll()
        hoveredCell = nil

        if viewModel.isEmpty {
            let label = makeLabel(L10n.switcherEmpty, font: DS.fontBody, color: DS.textSecondary)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            cells.append(label)
            return
        }

        for (index, hit) in viewModel.hits.enumerated() {
            let cell: NSView
            switch mode {
            case .icons:
                cell = makeIconCell(title: hit.window.windowTitle.isEmpty ? hit.window.appName : hit.window.windowTitle,
                                    icon: hit.window.appIcon,
                                    selected: index == viewModel.selectedIndex)
            case .thumbnails:
                cell = makeThumbnailCell(hit: hit,
                                         selected: index == viewModel.selectedIndex)
            }
            addSubview(cell)
            attachGestures(to: cell, index: index)
            cells.append(cell)
        }
        layoutCells()
    }

    // MARK: - Cells

    private func makeIconCell(title: String, icon: NSImage?, selected: Bool) -> NSView {
        let cell = NSView()
        cell.wantsLayer = true
        cell.layer?.cornerRadius = DS.radiusCard
        cell.layer?.cornerCurve = .continuous

        let iconView = NSImageView()
        iconView.image = icon ?? NSApp.applicationIconImage
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = makeLabel(title, font: DS.fontCaption, color: DS.textPrimary)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(iconView)
        cell.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: cell.topAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 46),
            iconView.heightAnchor.constraint(equalToConstant: 46),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
        ])
        applyCellBackground(cell, selected: selected, hover: false)
        return cell
    }

    private func makeThumbnailCell(hit: SearchHit, selected: Bool) -> NSView {
        let window = hit.window
        let cell = NSView()
        cell.wantsLayer = true
        cell.layer?.cornerRadius = DS.radiusCard
        cell.layer?.cornerCurve = .continuous

        // Thumbnail area: inset app-icon placeholder until the capture lands.
        let thumbnailContainer = NSView()
        thumbnailContainer.translatesAutoresizingMaskIntoConstraints = false
        thumbnailContainer.wantsLayer = true
        thumbnailContainer.layer?.cornerRadius = DS.radiusControl
        thumbnailContainer.layer?.cornerCurve = .continuous
        thumbnailContainer.layer?.masksToBounds = true

        let thumbnailView = NSImageView()
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.isHidden = true // shown when a real capture arrives

        let placeholderView = NSImageView()
        placeholderView.image = window.appIcon
        placeholderView.imageScaling = .scaleNone
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        placeholderView.setContentCompressionResistancePriority(.required, for: .horizontal)
        placeholderView.setContentHuggingPriority(.required, for: .horizontal)

        thumbnailContainer.addSubview(thumbnailView)
        thumbnailContainer.addSubview(placeholderView)

        let title = window.windowTitle.isEmpty ? window.appName : window.windowTitle
        let titleLabel = makeLabel(title, font: DS.fontCaption, color: DS.textPrimary)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = window.appIcon
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let appLabel = makeLabel(window.appName, font: DS.fontCaption, color: DS.textSecondary)
        appLabel.lineBreakMode = .byTruncatingTail
        appLabel.maximumNumberOfLines = 1
        appLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeStack = NSStackView()
        badgeStack.orientation = .horizontal
        badgeStack.spacing = 4
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        for badge in SwitcherListView.badges(for: window) {
            let imageView = NSImageView(image: NSImage(systemSymbolName: badge.symbol, accessibilityDescription: badge.label)!)
            imageView.contentTintColor = DS.textTertiary
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 11),
                imageView.heightAnchor.constraint(equalToConstant: 11),
            ])
            badgeStack.addArrangedSubview(imageView)
        }

        cell.addSubview(thumbnailContainer)
        cell.addSubview(badgeStack)
        cell.addSubview(iconView)
        cell.addSubview(titleLabel)
        cell.addSubview(appLabel)
        NSLayoutConstraint.activate([
            thumbnailContainer.topAnchor.constraint(equalTo: cell.topAnchor),
            thumbnailContainer.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            thumbnailContainer.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            thumbnailContainer.heightAnchor.constraint(equalToConstant: thumbnailSize.thumbnailHeight),
            thumbnailView.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor),
            placeholderView.centerXAnchor.constraint(equalTo: thumbnailContainer.centerXAnchor),
            placeholderView.centerYAnchor.constraint(equalTo: thumbnailContainer.centerYAnchor),
            placeholderView.widthAnchor.constraint(equalToConstant: 44),
            placeholderView.heightAnchor.constraint(equalToConstant: 44),
            badgeStack.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor, constant: 6),
            badgeStack.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor, constant: 6),
            iconView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            iconView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: appLabel.centerYAnchor),
            titleLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 8),
            appLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: appLabel.leadingAnchor, constant: -6),
        ])
        applyCellBackground(cell, selected: selected, hover: false)

        // Async capture; cancelled when cells are rebuilt.
        let cellID = ObjectIdentifier(cell)
        let size = CGSize(width: thumbnailSize.cardWidth, height: thumbnailSize.thumbnailHeight)
        let task = Task { [weak self, weak thumbnailView, weak placeholderView] in
            let image = await ThumbnailProvider.shared.thumbnail(for: window, size: size)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let thumbnailView, self?.tasks[cellID] != nil else { return }
                if let image {
                    thumbnailView.image = image
                    thumbnailView.isHidden = false
                    placeholderView?.isHidden = true
                }
            }
        }
        tasks[cellID] = task
        return cell
    }

    // MARK: - Layout

    private func layoutCells() {
        guard !cells.isEmpty else { return }
        if cells.count == 1, cells[0] is NSTextField { return } // centered by constraints
        for (index, cell) in cells.enumerated() {
            let row = index / Self.gridColumns
            let column = index % Self.gridColumns
            let x = Self.gridInset + CGFloat(column) * (cardWidth + Self.gridGap)
            let y = Self.gridInset + CGFloat(row) * rowHeight()
            cell.frame = NSRect(x: x, y: y, width: cardWidth, height: cardHeight)
        }
    }

    // MARK: - Selection & gestures

    private func applyCellBackground(_ cell: NSView, selected: Bool, hover: Bool) {
        cell.effectiveAppearance.performAsCurrentDrawingAppearance {
            let color: NSColor
            if selected {
                color = DS.selection
            } else if hover {
                color = DS.hover
            } else {
                color = .clear
            }
            cell.layer?.backgroundColor = color.cgColor
            cell.layer?.borderWidth = selected ? 1.0 : 0
            cell.layer?.borderColor = selected ? DS.accent.withAlphaComponent(0.55).cgColor : CGColor.clear
        }
    }

    func refreshAllSelections(selected: Int) {
        currentSelection = selected
        for (index, cell) in cells.enumerated() {
            applyCellBackground(cell, selected: index == selected, hover: cell == hoveredCell)
        }
    }

    /// Cheap selection re-tint without a full rebuild.
    func refreshSelectionPublic(previous: Int, current: Int) {
        currentSelection = current
        if previous < cells.count, previous >= 0 {
            applyCellBackground(cells[previous], selected: false, hover: false)
        }
        if current < cells.count, current >= 0 {
            applyCellBackground(cells[current], selected: true, hover: false)
        }
    }

    func noteSelection(_ index: Int) {
        currentSelection = index
    }

    private func attachGestures(to cell: NSView, index: Int) {
        cell.identifier = NSUserInterfaceItemIdentifier(String(index))
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self,
                                  userInfo: ["cell": cell])
        cell.addTrackingArea(area)
        let click = NSClickGestureRecognizer(target: self, action: #selector(cellClicked(_:)))
        cell.addGestureRecognizer(click)
    }

    override func mouseEntered(with event: NSEvent) {
        guard let cell = event.trackingArea?.userInfo?["cell"] as? NSView,
              let index = cell.identifier.flatMap({ Int($0.rawValue) }) else { return }
        hoveredCell = cell
        applyCellBackground(cell, selected: index == currentSelection, hover: true)
        onHoverIndex?(index)
    }

    override func mouseExited(with event: NSEvent) {
        guard let cell = event.trackingArea?.userInfo?["cell"] as? NSView,
              let index = cell.identifier.flatMap({ Int($0.rawValue) }) else { return }
        hoveredCell = nil
        applyCellBackground(cell, selected: index == currentSelection, hover: false)
    }

    @objc private func cellClicked(_ gesture: NSClickGestureRecognizer) {
        guard let identifier = gesture.view?.identifier,
              let index = Int(identifier.rawValue) else { return }
        onConfirmIndex?(index)
    }

    func cancelAllTasks() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
