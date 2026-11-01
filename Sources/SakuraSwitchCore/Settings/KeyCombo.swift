import Foundation
import AppKit
import Carbon.HIToolbox

/// A global hotkey combination, stored in Carbon terms because
/// `RegisterEventHotKey` consumes Carbon virtual key codes and modifier masks.
public struct KeyCombo: Codable, Hashable {
    /// Carbon virtual key code (e.g. `kVK_Tab`).
    public var keyCode: UInt32
    /// Carbon modifier mask (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`).
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // Carbon modifier masks (re-declared as constants for clarity).
    public static let command: UInt32 = UInt32(cmdKey)      // 0x0100
    public static let shift: UInt32 = UInt32(shiftKey)      // 0x0200
    public static let option: UInt32 = UInt32(optionKey)    // 0x0800
    public static let control: UInt32 = UInt32(controlKey)  // 0x1000

    public static let allModifierMask: UInt32 = command | shift | option | control

    public var hasModifier: Bool { modifiers != 0 }

    /// Modifier glyphs in macOS display order: ⌃ ⌥ ⇧ ⌘
    public var modifierDisplayString: String {
        var out = ""
        if modifiers & KeyCombo.control != 0 { out += "⌃" }
        if modifiers & KeyCombo.option != 0 { out += "⌥" }
        if modifiers & KeyCombo.shift != 0 { out += "⇧" }
        if modifiers & KeyCombo.command != 0 { out += "⌘" }
        return out
    }

    /// Human readable key name for common Carbon key codes.
    public var keyDisplayString: String {
        switch Int(keyCode) {
        case kVK_Tab: return "Tab"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_ANSI_Grave: return "`"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: break
        }
        if let letter = Self.letter(forKeyCode: keyCode) { return letter }
        if let digit = Self.digit(forKeyCode: keyCode) { return digit }
        return "Key(\(keyCode))"
    }

    public var displayString: String {
        modifierDisplayString + keyDisplayString
    }

    /// `kVK_ANSI_A` = 0 … `kVK_ANSI_Z` = 25.
    public static func letter(forKeyCode keyCode: UInt32) -> String? {
        let code = Int(keyCode)
        guard (0...25).contains(code) else { return nil }
        return String(UnicodeScalar(UInt8(97 + code))).uppercased()
    }

    /// `kVK_ANSI_0` = 29 … `kVK_ANSI_9` = 18 (not contiguous).
    public static func digit(forKeyCode keyCode: UInt32) -> String? {
        let map: [Int: String] = [
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        ]
        return map[Int(keyCode)]
    }

    /// Convert `NSEvent.ModifierFlags` (as seen in key recorders) to a Carbon mask.
    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= KeyCombo.command }
        if flags.contains(.option) { mask |= KeyCombo.option }
        if flags.contains(.shift) { mask |= KeyCombo.shift }
        if flags.contains(.control) { mask |= KeyCombo.control }
        return mask
    }
}
