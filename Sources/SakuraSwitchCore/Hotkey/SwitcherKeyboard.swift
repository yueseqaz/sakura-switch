import Carbon.HIToolbox

/// Shared navigation rules for the global event tap and local fallback.
public enum SwitcherKeyboard {
    public enum Action: Equatable {
        case step(Int)
        case confirm
        case escape
    }

    public enum ReleaseAction: Equatable {
        case none
        case confirm
        case keepOpen
    }

    public static func action(keyCode: UInt16, modifiers: UInt32, trigger: KeyCombo?) -> Action? {
        let base = modifiers & ~KeyCombo.shift
        let triggerBase = trigger.map { $0.modifiers & ~KeyCombo.shift }
        guard base == 0 || base == triggerBase else { return nil }

        switch Int(keyCode) {
        case kVK_Tab:
            return .step(modifiers & KeyCombo.shift == 0 ? 1 : -1)
        case kVK_LeftArrow, kVK_UpArrow:
            return .step(-1)
        case kVK_RightArrow, kVK_DownArrow:
            return .step(1)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            return .confirm
        case kVK_Escape:
            return .escape
        default:
            if let trigger, UInt32(keyCode) == trigger.keyCode,
               modifiers & trigger.modifiers == trigger.modifiers {
                return .step(modifiers & KeyCombo.shift == 0 ? 1 : -1)
            }
            return nil
        }
    }

    public static func shouldConfirmOnRelease(modifiers: UInt32,
                                              trigger: KeyCombo?,
                                              behavior: AppSettings.Hotkeys.ReleaseBehavior = .switchAndClose) -> Bool {
        releaseAction(modifiers: modifiers, trigger: trigger, behavior: behavior) == .confirm
    }

    public static func releaseAction(modifiers: UInt32, trigger: KeyCombo?,
                                     behavior: AppSettings.Hotkeys.ReleaseBehavior) -> ReleaseAction {
        guard let trigger, trigger.modifiers != 0,
              modifiers & trigger.modifiers != trigger.modifiers else { return .none }
        return behavior == .keepOpen ? .keepOpen : .confirm
    }
}
