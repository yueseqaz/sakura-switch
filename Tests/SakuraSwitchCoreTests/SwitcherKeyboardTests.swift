import Carbon.HIToolbox
import Testing
@testable import SakuraSwitchCore

@Suite("Hold-modifier window navigation")
struct SwitcherKeyboardTests {
    private let trigger = KeyCombo(keyCode: UInt32(kVK_Tab), modifiers: KeyCombo.option)

    @Test("Option stays held while Tab cycles and Shift reverses")
    func optionTab() {
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_Tab), modifiers: KeyCombo.option, trigger: trigger) == .step(1))
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_Tab), modifiers: KeyCombo.option | KeyCombo.shift, trigger: trigger) == .step(-1))
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_Tab), modifiers: KeyCombo.option | KeyCombo.command, trigger: trigger) == nil)
    }

    @Test("Held Option still permits arrows, Enter and Escape")
    func heldNavigation() {
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_RightArrow), modifiers: KeyCombo.option, trigger: trigger) == .step(1))
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_LeftArrow), modifiers: KeyCombo.option, trigger: trigger) == .step(-1))
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_Escape), modifiers: KeyCombo.option, trigger: trigger) == .escape)
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_Return), modifiers: KeyCombo.option, trigger: trigger) == .confirm)
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_ANSI_A), modifiers: KeyCombo.option, trigger: trigger) == nil)
    }

    @Test("Custom trigger repeats and plain Tab both navigate")
    func customTrigger() {
        let custom = KeyCombo(keyCode: UInt32(kVK_ANSI_Grave), modifiers: KeyCombo.control | KeyCombo.option)
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_ANSI_Grave), modifiers: custom.modifiers, trigger: custom) == .step(1))
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_ANSI_Grave), modifiers: custom.modifiers | KeyCombo.shift, trigger: custom) == .step(-1))
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_ANSI_Grave), modifiers: 0, trigger: custom) == nil)
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_Tab), modifiers: 0, trigger: custom) == .step(1))
    }

    @Test("Release confirms only for a hotkey session, not a menu session")
    func release() {
        #expect(!SwitcherKeyboard.shouldConfirmOnRelease(modifiers: KeyCombo.option | KeyCombo.shift, trigger: trigger))
        #expect(!SwitcherKeyboard.shouldConfirmOnRelease(modifiers: KeyCombo.option, trigger: trigger))
        #expect(SwitcherKeyboard.shouldConfirmOnRelease(modifiers: 0, trigger: trigger))
        #expect(SwitcherKeyboard.shouldConfirmOnRelease(modifiers: KeyCombo.shift, trigger: trigger))
        #expect(!SwitcherKeyboard.shouldConfirmOnRelease(modifiers: 0, trigger: trigger, behavior: .keepOpen))
        #expect(!SwitcherKeyboard.shouldConfirmOnRelease(modifiers: 0, trigger: nil))
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_Tab), modifiers: 0, trigger: nil) == .step(1))
        #expect(SwitcherKeyboard.action(keyCode: UInt16(kVK_Tab), modifiers: KeyCombo.option, trigger: nil) == nil)
    }

    @Test("Quick release and flags-change paths share the chosen behavior")
    func releaseDecision() {
        #expect(SwitcherKeyboard.releaseAction(modifiers: 0, trigger: trigger, behavior: .keepOpen) == .keepOpen)
        #expect(SwitcherKeyboard.releaseAction(modifiers: 0, trigger: trigger, behavior: .switchAndClose) == .confirm)
        #expect(SwitcherKeyboard.releaseAction(modifiers: KeyCombo.option, trigger: trigger, behavior: .keepOpen) == .none)
        #expect(SwitcherKeyboard.releaseAction(modifiers: 0, trigger: nil, behavior: .keepOpen) == .none)
    }
}
