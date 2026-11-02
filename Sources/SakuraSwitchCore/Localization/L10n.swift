import Foundation

/// Lightweight localization without .lproj bundles.
/// Language resolution: explicit setting (中文 / English) or system preference.
public enum L10n {

    /// Current language, updated by the settings store at launch and on change.
    public static var language: AppSettings.AppLanguage = .system

    public static var isChinese: Bool {
        switch language {
        case .zhHans: return true
        case .en: return false
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.lowercased().hasPrefix("zh")
        }
    }

    private static func t(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }

    // MARK: - App

    public static var appName: String { t("樱花切换", "Sakura Switch") }

    // MARK: - Menu bar

    public static var menuOpenSwitcher: String { t("打开切换器", "Open Switcher") }
    public static var menuSettings: String { t("设置…", "Settings…") }
    public static var menuAbout: String { t("关于 Sakura Switch", "About Sakura Switch") }
    public static var menuQuit: String { t("退出 Sakura Switch", "Quit Sakura Switch") }
    public static var menuCheckAccessibility: String { t("授予辅助功能权限…", "Grant Accessibility Permission…") }

    // MARK: - Switcher

    public static var switcherSearchPlaceholder: String { t("搜索窗口…", "Search windows…") }
    public static var switcherEmpty: String { t("没有可切换的窗口", "No windows to switch") }
    public static var switcherNoResults: String { t("没有匹配的窗口", "No matching windows") }
    public static var switcherPermissionMissingTitle: String { t("需要辅助功能权限", "Accessibility Permission Required") }
    public static var switcherPermissionMissingBody: String {
        t("Sakura Switch 需要辅助功能权限才能列出并切换其他应用的窗口。请在系统设置中授权，无需重启应用。",
          "Sakura Switch needs Accessibility permission to list and switch other apps' windows. Grant it in System Settings; no restart required.")
    }
    public static var switcherOpenSystemSettings: String { t("打开系统设置", "Open System Settings") }
    public static var switcherCancel: String { t("稍后再说", "Later") }
    public static var switcherScreenCaptureNeeded: String { t("开启缩略图需要屏幕录制权限", "Thumbnails need Screen Recording permission") }
    public static var switcherAllWindows: String { t("全部窗口", "All windows") }
    public static var switcherPreviewLoading: String { t("正在加载预览…", "Loading preview…") }
    public static var switcherPreviewUnavailable: String { t("此窗口暂不可预览", "Preview unavailable") }
    public static func switcherWindowCount(_ count: Int) -> String { t("\(count) 个窗口", "\(count) windows") }

    // MARK: - Badges

    public static var badgeMinimized: String { t("已最小化", "Minimized") }
    public static var badgeFullscreen: String { t("全屏", "Fullscreen") }
    public static var badgeOtherSpace: String { t("其他桌面", "Other Desktop") }

    // MARK: - Settings

    public static var settingsTitle: String { t("Sakura Switch 设置", "Sakura Switch Settings") }
    public static var tabGeneral: String { t("通用", "General") }
    public static var tabHotkeys: String { t("快捷键", "Hotkeys") }
    public static var tabAppearance: String { t("外观", "Appearance") }
    public static var tabWindowBehavior: String { t("窗口行为", "Window Behavior") }
    public static var tabExclusions: String { t("排除列表", "Exclusions") }
    public static var tabSearch: String { t("搜索", "Search") }
    public static var tabPermissions: String { t("权限", "Permissions") }
    public static var tabAbout: String { t("关于", "About") }

    // General
    public static var generalLaunchAtLogin: String { t("开机启动", "Launch at Login") }
    public static var generalLaunchAtLoginHint: String { t("登录时自动在后台启动 Sakura Switch", "Start Sakura Switch in the background when you log in") }
    public static var generalLanguage: String { t("语言", "Language") }
    public static var languageSystem: String { t("跟随系统", "Follow System") }
    public static var languageZh: String { t("简体中文", "简体中文") }
    public static var languageEn: String { t("English", "English") }
    public static var launchAtLoginFailed: String { t("无法设置开机启动", "Could not update launch-at-login") }

    // Hotkeys
    public static var hotkeyGlobal: String { t("全局切换窗口", "Global Window Switching") }
    public static var hotkeyGlobalHint: String { t("在任何应用中唤起切换器，默认 ⌥ Tab", "Summon the switcher from any app, default ⌥ Tab") }
    public static var hotkeyInApp: String { t("应用内切换窗口", "In-app Window Cycling") }
    public static var hotkeyInAppHint: String { t("在当前应用的多个窗口间循环，默认 ⌥ `", "Cycle between windows of the current app, default ⌥ `") }
    public static var hotkeyRecord: String { t("点击录制", "Click to Record") }
    public static var hotkeyRecording: String { t("按下新的快捷键…", "Press a new shortcut…") }
    public static var hotkeyResetDefaults: String { t("恢复默认", "Reset to Defaults") }
    public static var hotkeyConflict: String { t("注册失败：该快捷键可能已被其他应用占用", "Registration failed: this shortcut may be taken by another app") }
    public static var hotkeyNeedsModifier: String { t("快捷键需要至少一个修饰键（⌃⌥⇧⌘）", "Shortcuts need at least one modifier (⌃⌥⇧⌘)") }
    public static var hotkeyHintRelease: String { t("按住修饰键保持面板；可选择松开后的行为，Esc 取消", "Hold the modifier to keep the panel open; choose what happens on release. Esc cancels") }
    public static var hotkeyReleaseBehavior: String { t("松开修饰键时", "When the modifier is released") }
    public static var hotkeyReleaseSwitchAndClose: String { t("切换并关闭面板", "Switch and close panel") }
    public static var hotkeyReleaseKeepOpen: String { t("保留面板打开", "Keep panel open") }

    // Appearance
    public static var appearanceViewMode: String { t("视图模式", "View Mode") }
    public static var viewModeThumbnails: String { t("缩略图", "Thumbnails") }
    public static var viewModeIcons: String { t("应用图标", "App Icons") }
    public static var viewModeTitles: String { t("标题列表", "Title List") }
    public static var appearanceTheme: String { t("外观", "Appearance") }
    public static var themeSystem: String { t("跟随系统", "System") }
    public static var themeLight: String { t("浅色", "Light") }
    public static var themeDark: String { t("深色", "Dark") }
    public static var appearanceMaterial: String { t("面板背景", "Panel Background") }
    public static var materialHud: String { t("深色毛玻璃", "Dark Frosted") }
    public static var materialPopover: String { t("浅色毛玻璃", "Light Frosted") }
    public static var materialUnderWindow: String { t("中性毛玻璃", "Neutral Frosted") }
    public static var appearanceThumbnailSize: String { t("缩略图大小", "Thumbnail Size") }
    public static var sizeSmall: String { t("小", "Small") }
    public static var sizeMedium: String { t("中", "Medium") }
    public static var sizeLarge: String { t("大", "Large") }

    // Window behavior
    public static var behaviorShowMinimized: String { t("显示最小化窗口", "Show minimized windows") }
    public static var behaviorShowFullscreen: String { t("显示全屏窗口", "Show fullscreen windows") }
    public static var behaviorShowOtherSpace: String { t("显示其他桌面的窗口", "Show windows on other desktops (Spaces)") }
    public static var behaviorFilterByScreen: String { t("仅列出当前屏幕上的窗口", "Only list windows on the current screen") }

    // Exclusions
    public static var exclusionsHint: String { t("以下 Bundle ID 的应用不会出现在切换器中。", "Apps with these bundle IDs never appear in the switcher.") }
    public static var exclusionsAddPlaceholder: String { t("输入 Bundle ID，例如 com.apple.finder", "Enter a bundle ID, e.g. com.apple.finder") }
    public static var exclusionsAdd: String { t("添加", "Add") }
    public static var exclusionsEmpty: String { t("暂无排除项", "No exclusions yet") }
    public static var exclusionsInvalid: String { t("请输入有效的 Bundle ID（形如 com.example.app）", "Enter a valid bundle ID (like com.example.app)") }
    public static var exclusionsDuplicate: String { t("该 Bundle ID 已在列表中", "This bundle ID is already listed") }
    public static var exclusionsRemove: String { t("移除", "Remove") }

    // Search settings
    public static var searchFuzzy: String { t("启用模糊搜索", "Enable fuzzy search") }
    public static var searchFuzzyHint: String { t("子序列匹配，如输入 vs 命中 Visual Studio Code", "Subsequence matching, e.g. “vs” matches Visual Studio Code") }
    public static var searchMemory: String { t("记住搜索缩写", "Remember search abbreviations") }
    public static var searchMemoryHint: String { t("选中结果后，下次同样的输入会优先命中该窗口", "After you pick a result, the same query will rank that window first next time") }
    public static var searchClearMemory: String { t("清除搜索记忆", "Clear Search Memory") }
    public static var searchMemoryCleared: String { t("已清除", "Cleared") }

    // Permissions
    public static var permissionAccessibility: String { t("辅助功能", "Accessibility") }
    public static var permissionAccessibilityPurpose: String { t("必需。用于枚举、前置和操控其他应用的窗口。", "Required. Used to enumerate, raise and control other apps' windows.") }
    public static var permissionScreenRecording: String { t("屏幕录制", "Screen Recording") }
    public static var permissionScreenRecordingPurpose: String { t("可选。仅在开启缩略图预览时需要，未授权时显示应用图标。", "Optional. Only needed for thumbnails; without it you'll see app icons.") }
    public static var permissionGranted: String { t("已授权", "Granted") }
    public static var permissionDenied: String { t("未授权", "Not Granted") }
    public static var permissionRecheck: String { t("重新检测", "Recheck") }
    public static var permissionOpenSettings: String { t("打开系统设置", "Open System Settings") }
    public static var permissionUnsignedNote: String {
        t("提示：更新或重新编译后，如授权不生效，请退出应用，在系统设置中移除旧条目，再重新添加当前 App。屏幕录制授权后可能需要重启应用。",
          "If permission stops working after an update or rebuild, quit the app, remove its old entry in System Settings, then add the current app again. Screen Recording may require an app restart.")
    }

    // About
    public static var aboutVersion: String { t("版本", "Version") }
    public static var aboutGitHub: String { t("GitHub 项目主页", "GitHub Project") }
    public static var aboutLicense: String { t("MIT License", "MIT License") }
    public static var aboutBuildNote: String { t("本应用使用 Swift Package Manager 从命令行构建，未经 Apple 公证。", "Built from the command line with Swift Package Manager; not notarized by Apple.") }
    public static var aboutCopyright: String { t("以 MIT 许可证开源发布", "Released as open source under the MIT license") }

    // Quick actions (shown as key hints)
    public static var actionClose: String { t("关闭", "Close") }
    public static var actionMinimize: String { t("最小化", "Minimize") }
    public static var actionFullscreen: String { t("全屏", "Fullscreen") }
    public static var actionQuit: String { t("退出应用", "Quit App") }
    public static var actionHide: String { t("隐藏应用", "Hide App") }
    public static var actionReveal: String { t("在 Finder 中显示", "Reveal in Finder") }
}
