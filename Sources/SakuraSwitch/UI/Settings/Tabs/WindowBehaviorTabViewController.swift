import AppKit
import SakuraSwitchCore

/// Window behavior: which windows appear in the switcher.
final class WindowBehaviorTabViewController: SettingsTabViewController {

    init() {
        super.init { Self.buildContent() }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    private static func buildContent() -> [NSView] {
        let context = AppContext.shared
        let behavior = context.settings.current.windowBehavior

        func switchRow(title: String,
                       isOn: Bool,
                       keyPath: @escaping (inout AppSettings.WindowBehavior, Bool) -> Void) -> NSView {
            let toggle = ClosureSwitch(isOn: isOn) { on in
                context.settings.update { keyPath(&$0.windowBehavior, on) }
            }
            toggle.setAccessibilityLabel(title)
            return DSForm.row(title: title, control: toggle)
        }

        return [
            makeLabel(L10n.tabWindowBehavior, font: DS.fontTitle, color: DS.textPrimary),
            DSForm.card(rows: [
                switchRow(title: L10n.behaviorShowMinimized,
                          isOn: behavior.showMinimized) { $0.showMinimized = $1 },
                DSForm.divider(),
                switchRow(title: L10n.behaviorShowFullscreen,
                          isOn: behavior.showFullscreen) { $0.showFullscreen = $1 },
                DSForm.divider(),
                switchRow(title: L10n.behaviorShowOtherSpace,
                          isOn: behavior.showOtherSpace) { $0.showOtherSpace = $1 },
                DSForm.divider(),
                switchRow(title: L10n.behaviorFilterByScreen,
                          isOn: behavior.filterByActiveScreen) { $0.filterByActiveScreen = $1 },
            ]),
        ]
    }
}
