import Foundation
import ApplicationServices
import CoreGraphics

/// Typed helpers around the raw Accessibility API.
/// Every AX call is guarded by a 0.25 s messaging timeout so a hung app can
/// never freeze the switcher.
public enum AXHelper {

    public static let messagingTimeout: Float = 0.25

    // MARK: - Element creation

    public static func applicationElement(pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }

    public static func systemWideElement() -> AXUIElement {
        let element = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }

    // MARK: - Attribute reads

    public static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard status == .success else { return nil }
        return value
    }

    public static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    public static func bool(_ element: AXUIElement, _ name: String) -> Bool? {
        guard let number = attribute(element, name) as? NSNumber else { return nil }
        return number.boolValue
    }

    public static func array(_ element: AXUIElement, _ name: String) -> [AXUIElement]? {
        attribute(element, name) as? [AXUIElement]
    }

    /// Position + size combined into a CGRect (global top-left coordinates,
    /// same space as CGWindow bounds).
    public static func frame(_ element: AXUIElement) -> CGRect? {
        guard let rawPosition = attribute(element, kAXPositionAttribute),
              CFGetTypeID(rawPosition) == AXValueGetTypeID(),
              let rawSize = attribute(element, kAXSizeAttribute),
              CFGetTypeID(rawSize) == AXValueGetTypeID() else { return nil }
        let positionValue = unsafeDowncast(rawPosition, to: AXValue.self)
        let sizeValue = unsafeDowncast(rawSize, to: AXValue.self)
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue, .cgPoint, &point)
        AXValueGetValue(sizeValue, .cgSize, &size)
        guard size.width >= 0, size.height >= 0 else { return nil }
        return CGRect(origin: point, size: size)
    }

    // MARK: - Attribute writes

    @discardableResult
    public static func setBool(_ element: AXUIElement, _ name: String, _ value: Bool) -> Bool {
        let number = NSNumber(value: value)
        return AXUIElementSetAttributeValue(element, name as CFString, number) == .success
    }

    // MARK: - Actions

    @discardableResult
    public static func perform(_ element: AXUIElement, _ action: String) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    // MARK: - Composite reads

    /// Build a snapshot of one AX window (used by the enumerator).
    public static func windowSnapshot(pid: pid_t, element: AXUIElement) -> AXWindowSnapshot? {
        let role = string(element, kAXRoleAttribute) ?? ""
        let subrole = string(element, kAXSubroleAttribute) ?? ""
        guard WindowAligner.isSwitchable(role: role, subrole: subrole) else { return nil }
        guard let frame = frame(element), frame.width > 1, frame.height > 1 else { return nil }
        let title = string(element, kAXTitleAttribute) ?? ""
        let minimized = bool(element, kAXMinimizedAttribute) ?? false
        let fullscreen = bool(element, "AXFullScreen") ?? false
        return AXWindowSnapshot(pid: pid,
                                title: title,
                                frame: frame,
                                role: role,
                                subrole: subrole,
                                isMinimized: minimized,
                                isFullscreen: fullscreen)
    }
}
