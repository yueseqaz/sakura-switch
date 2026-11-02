import AppKit
import CoreGraphics
import SakuraSwitchCore

/// Session-level CGEvent tap that intercepts keyboard events while the
/// switcher panel is visible — the AltTab architecture. Works regardless of
/// which app is active; requires the Accessibility permission, which the
/// switcher already demands before showing.
@MainActor
final class KeyboardInterceptor {

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var userInfoBox: Unmanaged<KeyboardInterceptor>?

    /// Returns true when the event was consumed (should not reach other apps).
    /// Called on the main thread (the tap source is added to the main run loop).
    var handler: ((NSEvent) -> Bool)?

    @discardableResult
    func start() -> Bool {
        stop()
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let box = Unmanaged.passRetained(self)
        userInfoBox = box
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: mask,
                                          callback: Self.tapCallback,
                                          userInfo: box.toOpaque()) else {
            Log.switcher.error("CGEvent tap creation failed (Accessibility missing?)")
            box.release()
            userInfoBox = nil
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        userInfoBox?.release()
        userInfoBox = nil
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard type == .keyDown || type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }
        let interceptor = Unmanaged<KeyboardInterceptor>.fromOpaque(userInfo!).takeUnretainedValue()
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }
        let consumed = interceptor.handler?(nsEvent) ?? false
        return consumed ? nil : Unmanaged.passUnretained(event)
    }
}
