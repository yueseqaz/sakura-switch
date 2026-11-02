import AppKit
import SwiftUI
import SakuraSwitchCore

/// The floating switcher panel: borderless, non-activating, frosted glass.
final class SwitcherPanel: NSPanel {

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 720, height: 420),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)

        isFloatingPanel = true
        acceptsMouseMovedEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isRestorable = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        worksWhenModal = true
        animationBehavior = .utilityWindow

        // Frosted glass backdrop with a continuous rounded rect and a
        // hairline border — the core of the "subtle frosted glass" look.
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 720, height: 420))
        effect.translatesAutoresizingMaskIntoConstraints = false
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.material = Self.material(for: AppContext.shared.settings.current.appearance.panelMaterial)
        effect.wantsLayer = true
        effect.layer?.cornerRadius = DS.radiusPanel
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = DS.hairline.cgColor

        contentView = effect
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    static func material(for preference: AppSettings.PanelMaterial) -> NSVisualEffectView.Material {
        switch preference {
        case .hud: return .hudWindow
        case .popover: return .popover
        case .underWindow: return .underWindowBackground
        }
    }

    /// Swap the backdrop material when the setting changes.
    func applyMaterial(_ preference: AppSettings.PanelMaterial) {
        (contentView as? NSVisualEffectView)?.material = Self.material(for: preference)
    }
}
