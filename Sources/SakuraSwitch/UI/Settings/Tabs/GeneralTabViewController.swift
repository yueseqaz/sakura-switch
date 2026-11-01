import AppKit
import SakuraSwitchCore

/// General: launch at login + language.
final class GeneralTabViewController: SettingsTabViewController {

    init() {
        super.init { Self.buildContent() }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    private static func buildContent() -> [NSView] {
        let context = AppContext.shared

        // Launch at login. If the service rejects the change, reflect the
        // real state back onto the switch.
        var switchRef: ClosureSwitch?
        let launchSwitch = ClosureSwitch(isOn: LaunchAtLogin.isEnabled) { on in
            let ok = LaunchAtLogin.setEnabled(on)
            if ok {
                context.settings.update { $0.general.launchAtLogin = on }
            } else {
                NSSound.beep()
                DispatchQueue.main.async {
                    switchRef?.setOn(LaunchAtLogin.isEnabled)
                }
            }
        }
        switchRef = launchSwitch
        launchSwitch.setAccessibilityLabel(L10n.generalLaunchAtLogin)

        let launchRow = DSForm.row(title: L10n.generalLaunchAtLogin,
                                   hint: L10n.generalLaunchAtLoginHint,
                                   control: launchSwitch)

        // Language — keep titles aligned with the allCases order.
        let languages = Array(AppSettings.AppLanguage.allCases)
        let titles = languages.map { language -> String in
            switch language {
            case .system: return L10n.languageSystem
            case .zhHans: return L10n.languageZh
            case .en: return L10n.languageEn
            }
        }
        let popup = ClosurePopup(items: titles,
                                 selectedIndex: languages.firstIndex(of: context.settings.current.general.language) ?? 0) { index in
            guard index < languages.count else { return }
            context.settings.update { $0.general.language = languages[index] }
        }
        let languageRow = DSForm.row(title: L10n.generalLanguage, control: popup)

        let bundleRow = makeLabel("\(AppInfo.bundleID) · v\(AppInfo.version) (\(AppInfo.build))",
                                  font: DS.fontCaption, color: DS.textTertiary)

        return [
            makeLabel(L10n.tabGeneral, font: DS.fontTitle, color: DS.textPrimary),
            DSForm.card(rows: [launchRow]),
            DSForm.card(rows: [languageRow]),
            bundleRow,
        ]
    }
}
