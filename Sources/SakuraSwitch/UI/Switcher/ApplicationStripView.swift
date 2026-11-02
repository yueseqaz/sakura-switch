import AppKit
import SakuraSwitchCore

/// Hovering an app scopes the window grid; the strip stays put while browsing.
final class ApplicationStripView: NSScrollView {
    static let height: CGFloat = 84
    var onFocusApplication: ((String?) -> Void)?

    private let stack = NSStackView()
    private var buttons: [ApplicationHoverButton] = []
    private var signature = ""
    private var initialMouseLocation = NSEvent.mouseLocation

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        hasHorizontalScroller = true
        autohidesScrollers = true
        horizontalScrollElasticity = .allowed
        verticalScrollElasticity = .none
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 8, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView = stack
        NSLayoutConstraint.activate([
            stack.heightAnchor.constraint(equalTo: contentView.heightAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualTo: contentView.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    func update(groups: [ApplicationWindowGroup], focusedID: String?) {
        let nextSignature = groups.map { "\($0.id):\($0.windows.count):\($0.windows.first?.appName ?? "")" }.joined(separator: "|") + L10n.switcherAllWindows
        if nextSignature != signature {
            signature = nextSignature
            stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
            buttons.removeAll()
            addButton(title: L10n.switcherAllWindows,
                      icon: NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil),
                      count: groups.reduce(0) { $0 + $1.windows.count }, id: nil)
            for group in groups {
                guard let window = group.windows.first else { continue }
                addButton(title: window.appName, icon: window.appIcon, count: group.windows.count, id: group.id)
            }
        }
        for button in buttons {
            button.setSelected(button.applicationID == focusedID)
        }
    }

    private func addButton(title: String, icon: NSImage?, count: Int, id: String?) {
        let button = ApplicationHoverButton(title: title, icon: icon, count: count, applicationID: id)
        button.initialMouseLocation = initialMouseLocation
        button.onFocus = { [weak self] in self?.onFocusApplication?(id) }
        stack.addArrangedSubview(button)
        buttons.append(button)
    }

    func cancelPendingHover() {
        buttons.forEach { $0.cancelPendingHover() }
    }

    func prepareForPresentation() {
        initialMouseLocation = NSEvent.mouseLocation
        for button in buttons {
            button.cancelPendingHover()
            button.initialMouseLocation = initialMouseLocation
        }
    }
}

private final class ApplicationHoverButton: NSButton {
    let applicationID: String?
    var onFocus: (() -> Void)?
    private var hoverTask: Task<Void, Never>?
    private var selected = false
    var initialMouseLocation = NSEvent.mouseLocation

    init(title: String, icon: NSImage?, count: Int, applicationID: String?) {
        self.applicationID = applicationID
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = DS.radiusControl
        self.title = ""
        target = self
        action = #selector(focusApplication)
        toolTip = "\(title) · \(L10n.switcherWindowCount(count))"
        setAccessibilityLabel(toolTip)
        let imageView = NSImageView()
        imageView.image = icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        let label = makeLabel(title, font: DS.fontCaption, color: DS.textPrimary)
        label.alignment = .center
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        let countLabel = makeLabel(String(count), font: DS.fontCaptionMedium, color: DS.textSecondary)
        for subview in [imageView, label, countLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 86),
            heightAnchor.constraint(equalToConstant: 70),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 32),
            imageView.heightAnchor.constraint(equalToConstant: 32),
            countLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 5),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        scheduleHover()
    }

    override func mouseMoved(with event: NSEvent) {
        guard hoverTask == nil else { return }
        scheduleHover()
    }

    private func scheduleHover() {
        // Opening under a stationary pointer should keep the keyboard's selection.
        guard NSEvent.mouseLocation != initialMouseLocation else { return }
        cancelPendingHover()
        hoverTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            self?.onFocus?()
        }
    }

    override func mouseExited(with event: NSEvent) { cancelPendingHover() }

    func cancelPendingHover() {
        hoverTask?.cancel()
        hoverTask = nil
    }

    @objc private func focusApplication() {
        cancelPendingHover()
        onFocus?()
    }

    func setSelected(_ value: Bool) {
        selected = value
        refreshAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    private func refreshAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = (selected ? DS.selection : .clear).cgColor
            layer?.borderWidth = selected ? 1 : 0
            layer?.borderColor = DS.accent.withAlphaComponent(0.4).cgColor
        }
    }
}
