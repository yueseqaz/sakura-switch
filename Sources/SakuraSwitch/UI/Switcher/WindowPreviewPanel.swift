import AppKit
import SakuraSwitchCore

/// A mouse-transparent child panel keeps magnification out of the grid's layout
/// and hit testing, so entering the preview cannot move the hover target.
final class WindowPreviewPanel: NSPanel {
    private let imageView = NSImageView()
    private let titleLabel = makeLabel("", font: DS.fontBodyMedium, color: DS.textPrimary)
    private let statusLabel = makeLabel("", font: DS.fontCaption, color: DS.textSecondary)

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        animationBehavior = .none

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = DS.radiusCard
        effect.layer?.masksToBounds = true
        contentView = effect
        imageView.imageScaling = .scaleProportionallyUpOrDown
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.alignment = .center
        statusLabel.maximumNumberOfLines = 2
        for view in [imageView, titleLabel, statusLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(view)
        }
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -10),
            imageView.topAnchor.constraint(equalTo: effect.topAnchor, constant: 10),
            imageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -10),
            titleLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -12),
            titleLabel.heightAnchor.constraint(equalToConstant: 20),
            statusLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -12),
        ])
    }

    func show(window: WindowModel, image: NSImage?, anchor: NSRect, parent: NSWindow, cardSize: NSSize) -> CGSize {
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? parent.screen ?? NSScreen.main
        let visible = (screen?.visibleFrame ?? parent.frame).insetBy(dx: 12, dy: 12)
        // The grid card is intentionally compact. A stopped selection should
        // become a readable inspection surface, not a slightly larger tile.
        let maxImage = CGSize(width: min(max(cardSize.width * 3.2, 720), visible.width * 0.78) - 20,
                              height: min(max(cardSize.height * 3.0 + 64, 520), visible.height * 0.78) - 52)
        let imageSize = WindowPreviewGeometry.fittedSize(source: window.frame.size, bounds: maxImage)
        let width = imageSize.width + 20
        let height = imageSize.height + 52
        let origin = NSPoint(x: min(max(anchor.midX - width / 2, visible.minX), visible.maxX - width),
                             y: min(max(anchor.midY - height / 2, visible.minY), visible.maxY - height))
        setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        titleLabel.stringValue = window.windowTitle.isEmpty ? window.appName : "\(window.appName) · \(window.windowTitle)"
        imageView.image = image
        statusLabel.stringValue = ScreenCapturePermission.isGranted ? L10n.switcherPreviewLoading : L10n.switcherScreenCaptureNeeded
        statusLabel.isHidden = image != nil
        if self.parent !== parent {
            self.parent?.removeChildWindow(self)
            parent.addChildWindow(self, ordered: .above)
        }
        orderFrontRegardless()
        return CGSize(width: max(16, width - 20), height: max(16, height - 52))
    }

    func update(image: NSImage?) {
        if let image { imageView.image = image }
        statusLabel.isHidden = imageView.image != nil
        statusLabel.stringValue = ScreenCapturePermission.isGranted ? L10n.switcherPreviewUnavailable : L10n.switcherScreenCaptureNeeded
    }

    func dismiss() {
        orderOut(nil)
        parent?.removeChildWindow(self)
        imageView.image = nil
    }
}
