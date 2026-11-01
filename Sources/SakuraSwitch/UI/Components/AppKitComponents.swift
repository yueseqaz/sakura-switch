import AppKit
import SakuraSwitchCore

// MARK: - Label factory

func makeLabel(_ text: String, font: NSFont = DS.fontBody, color: NSColor = DS.textPrimary) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = font
    label.textColor = color
    label.lineBreakMode = .byWordWrapping
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
}

// MARK: - Card

/// Content card: barely lighter than the window background, hairline stroke,
/// no heavy shadow. Re-resolves its colors when the effective appearance
/// changes (light ⇄ dark).
final class DSCardView: NSView {
    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = DS.radiusCard) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.5
        refreshAppearance()
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    private func refreshAppearance() {
        layer?.backgroundColor = DS.card.cgColor
        layer?.borderColor = DS.hairline.cgColor
    }
}

// MARK: - Hover-capable custom button

/// Flat button with neutral light background, hairline stroke and a quiet
/// hover state. Used everywhere except explicit accent actions.
class DSButton: NSButton {
    enum Kind {
        case neutral, accent, danger, ghost

        var background: NSColor {
            switch self {
            case .neutral: return DS.control
            case .accent: return DS.accent
            case .danger: return DS.danger
            case .ghost: return .clear
            }
        }

        var foreground: NSColor {
            switch self {
            case .neutral, .ghost: return DS.textPrimary
            case .accent, .danger: return .white
            }
        }

        var hoverOverlay: CGColor {
            switch self {
            case .neutral: return NSColor.black.withAlphaComponent(0.05).cgColor
            case .accent, .danger: return NSColor.black.withAlphaComponent(0.12).cgColor
            case .ghost: return DS.hover.cgColor
            }
        }
    }

    private let kind: Kind
    var actionHandler: () -> Void
    private var trackingArea: NSTrackingArea?
    private var isHovering = false {
        didSet { updateVisuals() }
    }

    init(_ title: String, kind: Kind = .neutral, action: @escaping () -> Void) {
        self.kind = kind
        self.actionHandler = action
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        font = DS.fontCaptionMedium
        layer?.cornerRadius = DS.radiusControl
        layer?.cornerCurve = .continuous
        target = self
        self.action = #selector(clicked)
        updateVisuals()
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    @objc private func clicked() {
        actionHandler()
    }

    /// Intrinsic padding around the title.
    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        return NSSize(width: base.width + 20, height: max(base.height + 8, 24))
    }

    private func updateVisuals() {
        guard let layer else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.backgroundColor = (isHovering && isEnabled ? self.hoverColor() : self.kind.background).cgColor
            if self.kind != .ghost {
                layer.borderColor = DS.hairline.cgColor
                layer.borderWidth = 0.5
            } else {
                layer.borderWidth = 0
            }
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: DS.fontCaptionMedium,
            .foregroundColor: isEnabled ? kind.foreground : kind.foreground.withAlphaComponent(0.4),
        ]
        attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }

    private func hoverColor() -> NSColor {
        switch kind {
        case .neutral: return DS.control.blended(withFraction: 0.06, of: .black) ?? DS.control
        case .accent, .danger: return kind.background.blended(withFraction: 0.12, of: .black) ?? kind.background
        case .ghost: return DS.hover
        }
    }

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
        guard isEnabled else { return }
        isHovering = true
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        NSCursor.pop()
    }
}

// MARK: - Toggle switch row helpers

final class ClosureSwitch: NSSwitch {
    private var change: (Bool) -> Void
    private var suppress = false

    init(isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.change = onChange
        super.init(frame: .zero)
        state = isOn ? .on : .off
        target = self
        action = #selector(toggled)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    func setOn(_ on: Bool) {
        suppress = true
        state = on ? .on : .off
        suppress = false
    }

    @objc private func toggled() {
        guard !suppress else { return }
        change(state == .on)
    }
}

// MARK: - Row builders

enum DSForm {
    /// Horizontal row: title (+hint) on the left, control on the right.
    static func row(title: String,
                    hint: String? = nil,
                    control: NSView? = nil) -> NSStackView {
        let textStack = NSStackView(views: [makeLabel(title, font: DS.fontBody, color: DS.textPrimary)])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        if let hint, !hint.isEmpty {
            let hintLabel = makeLabel(hint, font: DS.fontCaption, color: DS.textSecondary)
            hintLabel.preferredMaxLayoutWidth = 380
            textStack.addArrangedSubview(hintLabel)
        }

        let row = NSStackView(views: [textStack])
        row.orientation = .horizontal
        row.alignment = control is NSSwitch ? .centerY : .firstBaseline
        row.spacing = DS.space2
        if let control {
            row.addView(control, in: .trailing)
            control.setContentHuggingPriority(.required, for: .horizontal)
            control.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        row.edgeInsets = NSEdgeInsets(top: 11, left: DS.space3, bottom: 11, right: DS.space3)
        row.distribution = .gravityAreas
        row.translatesAutoresizingMaskIntoConstraints = false
        // Text grows, control stays.
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return row
    }

    /// Hairline divider inset to align with row content.
    static func divider(leadingInset: CGFloat = DS.space3) -> NSView {
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = DS.hairline.cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leadingInset),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: container.topAnchor),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    /// Vertical stack of rows inside a card.
    static func card(rows: [NSView]) -> DSCardView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        for row in rows {
            row.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
            row.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        }
        let card = DSCardView()
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        ])
        return card
    }

    /// Note box: icon + text, quiet but always visible.
    static func note(_ text: String, tone: NoteTone = .info) -> NSView {
        let iconView = NSImageView()
        let symbolName: String
        switch tone {
        case .info: symbolName = "info.circle"
        case .warning: symbolName = "exclamationmark.triangle"
        case .error: symbolName = "xmark.octagon"
        }
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.contentTintColor = tone.color
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = makeLabel(text, font: NSFont.systemFont(ofSize: 11.5), color: DS.textSecondary)
        label.preferredMaxLayoutWidth = 520

        let stack = NSStackView(views: [iconView, label])
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = DS.space1
        stack.edgeInsets = NSEdgeInsets(top: DS.space2, left: DS.space2, bottom: DS.space2, right: DS.space2)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = DS.radiusControl
        box.layer?.cornerCurve = .continuous
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: box.trailingAnchor),
        ])

        func refresh() {
            box.layer?.backgroundColor = tone.color.withAlphaComponent(0.07).cgColor
        }
        refresh()

        return box
    }
}

enum NoteTone {
    case info, warning, error

    var color: NSColor {
        switch self {
        case .info: return DS.accent
        case .warning: return .systemOrange
        case .error: return DS.danger
        }
    }
}

// MARK: - Segmented control

final class ClosureSegmented: NSSegmentedControl {
    private var change: (Int) -> Void

    init(labels: [String], selectedIndex: Int, onChange: @escaping (Int) -> Void) {
        self.change = onChange
        super.init(frame: .zero)
        segmentStyle = .rounded
        segmentCount = labels.count
        for (index, label) in labels.enumerated() {
            setLabel(label, forSegment: index)
        }
        selectedSegment = selectedIndex
        target = self
        action = #selector(segmentChanged)
        translatesAutoresizingMaskIntoConstraints = false
        font = DS.fontCaption
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    @objc private func segmentChanged() {
        change(selectedSegment)
    }
}

// MARK: - Popup menu

final class ClosurePopup: NSPopUpButton {
    private var change: (Int) -> Void

    init(items: [String], selectedIndex: Int, width: CGFloat = 160, onChange: @escaping (Int) -> Void) {
        self.change = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 28), pullsDown: false)
        for item in items {
            addItem(withTitle: item)
        }
        selectItem(at: selectedIndex)
        target = self
        action = #selector(itemChanged)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    func select(_ index: Int) {
        selectItem(at: index)
    }

    @objc private func itemChanged() {
        change(selectedItem?.tag ?? indexOfSelectedItem)
    }
}
