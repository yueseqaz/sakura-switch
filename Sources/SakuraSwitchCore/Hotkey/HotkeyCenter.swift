import Foundation
import Carbon.HIToolbox

/// Global hotkeys via Carbon `RegisterEventHotKey` — no third-party libraries.
///
/// One event handler is installed for the process; each registered combo gets
/// a unique 32-bit id. Failures (conflicts with other apps' shortcuts) are
/// reported to the caller so the settings UI can surface them — never silent.
public final class HotkeyCenter {

    public static let shared = HotkeyCenter()

    private struct Registration {
        var combo: KeyCombo
        var hotKeyRef: EventHotKeyRef
    }

    private var handlerRef: EventHandlerRef?
    private var registrations: [String: Registration] = [:]
    private var nextID: UInt32 = 1
    private let queue = DispatchQueue(label: "com.yueseqaz.sakuraswitch.hotkeys")

    /// Called on the main thread with the hotkey's `id`.
    public var onKeyDown: ((String) -> Void)?

    private init() {
        installHandler()
    }

    deinit {
        // Event handler removal must happen on a thread that can run Carbon;
        // best effort in practice the app tears down at quit.
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    // MARK: - Public API

    /// Register (or re-register) a hotkey. Returns false when the OS rejects
    /// it (e.g. the combination is taken by another application).
    @discardableResult
    public func register(id: String, combo: KeyCombo) -> Bool {
        queue.sync { _register(id: id, combo: combo) }
    }

    @discardableResult
    public func unregister(id: String) -> Bool {
        queue.sync { _unregister(id: id) }
    }

    public func unregisterAll() {
        queue.sync {
            for (_, registration) in registrations {
                UnregisterEventHotKey(registration.hotKeyRef)
            }
            registrations.removeAll()
        }
    }

    public func combo(for id: String) -> KeyCombo? {
        queue.sync { registrations[id]?.combo }
    }

    /// All currently registered ids (for conflict checks in settings).
    public var registeredIDs: [String] {
        queue.sync { Array(registrations.keys) }
    }

    // MARK: - Implementation

    @discardableResult
    private func _register(id: String, combo: KeyCombo) -> Bool {
        // Replace an existing registration for this id first.
        _unregister(id: id)

        // A combo without any modifier would swallow a plain key system-wide.
        guard combo.hasModifier else { return false }

        let hotKeyID = EventHotKeyID(signature: OSType(0x534B5753) /* "SKWS" */, id: nextID)
        nextID &+= 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode,
                                         combo.modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        guard status == noErr, let hotKeyRef = ref else {
            Log.hotkey.error("RegisterEventHotKey failed for '\(id, privacy: .public)' status=\(status)")
            return false
        }

        hotKeyIDByCarbonID[hotKeyID.id] = id
        registrations[id] = Registration(combo: combo, hotKeyRef: hotKeyRef)
        Log.hotkey.info("Registered hotkey '\(id, privacy: .public)'")
        return true
    }

    @discardableResult
    private func _unregister(id: String) -> Bool {
        guard let registration = registrations.removeValue(forKey: id) else { return false }
        UnregisterEventHotKey(registration.hotKeyRef)
        hotKeyIDByCarbonID = hotKeyIDByCarbonID.filter { $0.value != id }
        Log.hotkey.info("Unregistered hotkey '\(id, privacy: .public)'")
        return true
    }

    /// Carbon event id → our string id.
    private var hotKeyIDByCarbonID: [UInt32: String] = [:]

    private func installHandler() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
        ]

        let callback: EventHandlerUPP = { _, event, _ in
            guard let event else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            guard status == noErr else { return noErr }
            let center = HotkeyCenter.shared
            guard let id = center.hotKeyIDByCarbonID[hotKeyID.id] else { return noErr }
            DispatchQueue.main.async {
                center.onKeyDown?(id)
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(),
                            callback,
                            eventTypes.count,
                            &eventTypes,
                            selfPtr,
                            &handlerRef)
    }
}
