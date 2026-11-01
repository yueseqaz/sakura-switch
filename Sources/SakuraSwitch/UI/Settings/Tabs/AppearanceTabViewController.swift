import AppKit
import SakuraSwitchCore

/// Appearance: view mode, theme, panel material, thumbnail size.
final class AppearanceTabViewController: SettingsTabViewController {

    init() {
        super.init { Self.buildContent() }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    private static func buildContent() -> [NSView] {
        let context = AppContext.shared
        let appearance = context.settings.current.appearance

        func segmented<T: CaseIterable & Equatable>(title: String,
                                                    allCases: [T],
                                                    titles: [String],
                                                    selected: T,
                                                    setter: @escaping (inout AppSettings, T) -> Void) -> NSView {
            let control = ClosureSegmented(labels: titles,
                                           selectedIndex: allCases.firstIndex(of: selected) ?? 0) { index in
                guard index < allCases.count else { return }
                let value = allCases[index]
                context.settings.update { setter(&$0, value) }
            }
            control.widthAnchor.constraint(equalToConstant: 250).isActive = true
            return DSForm.row(title: title, control: control)
        }

        let viewModeRow = segmented(title: L10n.appearanceViewMode,
                                    allCases: Array(AppSettings.ViewMode.allCases),
                                    titles: [L10n.viewModeThumbnails, L10n.viewModeIcons, L10n.viewModeTitles],
                                    selected: appearance.viewMode) { $0.appearance.viewMode = $1 }

        let themeRow = segmented(title: L10n.appearanceTheme,
                                 allCases: Array(AppSettings.ThemePreference.allCases),
                                 titles: [L10n.themeSystem, L10n.themeLight, L10n.themeDark],
                                 selected: appearance.theme) { $0.appearance.theme = $1 }

        let materialRow = segmented(title: L10n.appearanceMaterial,
                                    allCases: Array(AppSettings.PanelMaterial.allCases),
                                    titles: [L10n.materialHud, L10n.materialPopover, L10n.materialUnderWindow],
                                    selected: appearance.panelMaterial) { $0.appearance.panelMaterial = $1 }

        let sizeRow = segmented(title: L10n.appearanceThumbnailSize,
                                allCases: Array(AppSettings.ThumbnailSize.allCases),
                                titles: [L10n.sizeSmall, L10n.sizeMedium, L10n.sizeLarge],
                                selected: appearance.thumbnailSize) { $0.appearance.thumbnailSize = $1 }

        return [
            makeLabel(L10n.tabAppearance, font: DS.fontTitle, color: DS.textPrimary),
            DSForm.card(rows: [viewModeRow,
                               DSForm.divider(),
                               themeRow,
                               DSForm.divider(),
                               materialRow,
                               DSForm.divider(),
                               sizeRow]),
        ]
    }
}
