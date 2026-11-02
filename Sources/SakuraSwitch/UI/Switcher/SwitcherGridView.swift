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
    private var windows: [WindowModel] = []
    private var thumbnailImages: [String: NSImage] = [:]
    private var previewTask: Task<Void, Never>?
    private let selectionPreview = WindowPreviewPanel()
    private var initialMouseLocation = NSEvent.mouseLocation
    #if DEBUG
    private(set) var loadedThumbnailCount = 0
    #endif

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { dismissSelectionPreview() }
    }

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

    /// The capture keeps the source window's aspect ratio. Windows with a
    /// portrait layout therefore get a taller card than landscape windows.
    func thumbnailDimensions(for window: WindowModel) -> CGSize {
        let source = window.frame.size
        guard source.width > 1, source.height > 1 else {
            return CGSize(width: cardWidth, height: thumbnailSize.thumbnailHeight)
        }
        return WindowPreviewGeometry.fittedSize(source: source,
                                                bounds: CGSize(width: cardWidth, height: cardWidth * 1.25))
    }

    func cardHeight(for index: Int) -> CGFloat {
        guard mode == .thumbnails, windows.indices.contains(index) else { return cardHeight }
        return thumbnailDimensions(for: windows[index]).height + 30
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

    private func rowHeight(for row: Int) -> CGFloat {
        let first = row * Self.gridColumns
        let last = min(first + Self.gridColumns, windows.count)
        guard first < last else { return cardHeight + Self.gridGap }
        let tallest = (first..<last).map(cardHeight(for:)).max() ?? cardHeight
        return tallest + Self.gridGap
    }

    /// y offset (flipped coordinates) of the row containing `index`.
    func rowY(for index: Int) -> CGFloat {
        let row = index / Self.gridColumns
        var y = Self.gridInset
        for previousRow in 0..<row { y += rowHeight(for: previousRow) }
        return y
    }

    /// Full document height, including rows that are below the visible clip.
    var documentHeight: CGFloat {
        guard !windows.isEmpty else { return 56 }
        let rows = (windows.count + Self.gridColumns - 1) / Self.gridColumns
        var height = Self.gridInset
        for row in 0..<rows { height += rowHeight(for: row) }
        return height
    }

    /// Height used by the panel before scrolling begins.
    var visibleDocumentHeight: CGFloat {
        guard !windows.isEmpty else { return 56 }
        let rows = min((windows.count + Self.gridColumns - 1) / Self.gridColumns, 2)
        var height = Self.gridInset
        for row in 0..<rows { height += rowHeight(for: row) }
        return height
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

        let signature = viewModel.hits.map { "\($0.window.key):\($0.window.windowTitle):\($0.window.isMinimized):\($0.window.isFullscreen):\($0.window.frame.width)x\($0.window.frame.height)" }.joined(separator: ",")
            + "|\(mode == .icons ? "i" : "t")|\(thumbnailSize.rawValue)|\(ScreenCapturePermission.isGranted)"
        if signature == lastSignature {
            refreshAllSelections(selected: viewModel.selectedIndex)
            return
        }
        lastSignature = signature

        dismissSelectionPreview()
        cancelAllTasks()
        windows = viewModel.hits.map(\.window)
        thumbnailImages.removeAll()
        #if DEBUG
        loadedThumbnailCount = 0
        #endif
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
        let placeholderLabel = makeLabel(ScreenCapturePermission.isGranted ? L10n.switcherPreviewLoading : L10n.switcherScreenCaptureNeeded,
                                         font: DS.fontCaption, color: DS.textTertiary)
        placeholderLabel.alignment = .center
        placeholderLabel.maximumNumberOfLines = 2
        thumbnailContainer.addSubview(placeholderLabel)

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
            thumbnailContainer.heightAnchor.constraint(equalToConstant: thumbnailDimensions(for: window).height),
            thumbnailView.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor),
            placeholderView.centerXAnchor.constraint(equalTo: thumbnailContainer.centerXAnchor),
            placeholderView.centerYAnchor.constraint(equalTo: thumbnailContainer.centerYAnchor, constant: -10),
            placeholderView.widthAnchor.constraint(equalToConstant: 44),
            placeholderView.heightAnchor.constraint(equalToConstant: 44),
            placeholderLabel.topAnchor.constraint(equalTo: placeholderView.bottomAnchor, constant: 3),
            placeholderLabel.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor, constant: 6),
            placeholderLabel.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor, constant: -6),
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
        let size = thumbnailDimensions(for: window)
        let task = Task { [weak self, weak thumbnailView, weak placeholderView, weak placeholderLabel] in
            var image: NSImage?
            for attempt in 0..<3 {
                if attempt > 0 { try? await Task.sleep(nanoseconds: 700_000_000) }
                guard !Task.isCancelled else { return }
                image = await ThumbnailProvider.shared.thumbnail(for: window, size: size)
                if image != nil || !ScreenCapturePermission.isGranted { break }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let thumbnailView, self?.tasks[cellID] != nil else { return }
                if let image {
                    self?.thumbnailImages[window.key] = image
                    #if DEBUG
                    self?.loadedThumbnailCount += 1
                    #endif
                    thumbnailView.image = image
                    thumbnailView.isHidden = false
                    placeholderView?.isHidden = true
                    placeholderLabel?.isHidden = true
                } else {
                    placeholderLabel?.stringValue = ScreenCapturePermission.isGranted
                        ? L10n.switcherPreviewUnavailable : L10n.switcherScreenCaptureNeeded
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
            let column = index % Self.gridColumns
            let width = mode == .thumbnails && windows.indices.contains(index)
                ? thumbnailDimensions(for: windows[index]).width : cardWidth
            let x = Self.gridInset + CGFloat(column) * (cardWidth + Self.gridGap) + (cardWidth - width) / 2
            let y = rowY(for: index)
            cell.frame = NSRect(x: x, y: y, width: width, height: cardHeight(for: index))
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
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                  owner: self,
                                  userInfo: ["index": index])
        cell.addTrackingArea(area)
        let click = NSClickGestureRecognizer(target: self, action: #selector(cellClicked(_:)))
        cell.addGestureRecognizer(click)
    }

    override func mouseEntered(with event: NSEvent) {
        handleHover(event)
    }

    override func mouseMoved(with event: NSEvent) {
        handleHover(event)
    }

    private func handleHover(_ event: NSEvent) {
        guard NSEvent.mouseLocation != initialMouseLocation else { return }
        guard let index = event.trackingArea?.userInfo?["index"] as? Int,
              cells.indices.contains(index) else { return }
        let cell = cells[index]
        guard cell.trackingAreas.contains(where: { $0 === event.trackingArea }) else { return }
        guard hoveredCell !== cell else { return }
        hoveredCell = cell
        applyCellBackground(cell, selected: index == currentSelection, hover: true)
        onHoverIndex?(index)
    }

    override func mouseExited(with event: NSEvent) {
        guard let index = event.trackingArea?.userInfo?["index"] as? Int,
              cells.indices.contains(index) else { return }
        let cell = cells[index]
        guard cell.trackingAreas.contains(where: { $0 === event.trackingArea }) else { return }
        guard hoveredCell === cell else { return }
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

    func resetThumbnails() {
        dismissSelectionPreview()
        cancelAllTasks()
        lastSignature = ""
    }

    func prepareForPresentation() {
        initialMouseLocation = NSEvent.mouseLocation
        hoveredCell = nil
        dismissSelectionPreview()
    }

    /// Cancel the enlarged preview while the user is actively navigating.
    func dismissSelectionPreview() {
        previewTask?.cancel()
        previewTask = nil
        selectionPreview.dismiss()
    }

    /// Enlarge the currently selected window after a short pause. This is
    /// driven by selection, not pointer hover, so keyboard browsing behaves
    /// the same with or without a mouse nearby.
    func scheduleSelectionPreview(index: Int, delay: UInt64 = 520_000_000) {
        dismissSelectionPreview()
        guard mode == .thumbnails, windows.indices.contains(index) else { return }
        let model = windows[index]
        previewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self,
                  self.currentSelection == index,
                  self.cells.indices.contains(index),
                  let parent = self.window, parent.isVisible else { return }
            let cell = self.cells[index]
            let anchor = parent.convertToScreen(cell.convert(cell.bounds, to: nil))
            let size = self.selectionPreview.show(window: model, image: self.thumbnailImages[model.key],
                                                   anchor: anchor, parent: parent,
                                                   cardSize: self.thumbnailDimensions(for: model))
            let image = await ThumbnailProvider.shared.thumbnail(for: model, size: size)
            guard !Task.isCancelled, self.currentSelection == index else { return }
            self.selectionPreview.update(image: image)
        }
    }

    #if DEBUG
    func saveSelectionPreviewSnapshotForSelfTest() {
        guard let content = selectionPreview.contentView, selectionPreview.isVisible else {
            preconditionFailure("Selection preview was not shown")
        }
        precondition(selectionPreview.ignoresMouseEvents && !selectionPreview.canBecomeKey)
        content.layoutSubtreeIfNeeded()
        guard let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { return }
        content.cacheDisplay(in: content.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/sakura-selection-preview-selftest.png"))
        print("SELFTEST selection-preview=passed size=\(Int(selectionPreview.frame.width))x\(Int(selectionPreview.frame.height)) mouseTransparent=true")
        dismissSelectionPreview()
        precondition(!selectionPreview.isVisible && selectionPreview.parent == nil)
    }
    #endif
}
