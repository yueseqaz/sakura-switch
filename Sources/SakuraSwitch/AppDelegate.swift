import AppKit
import Combine
import SakuraSwitchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private weak var statusMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let context = AppContext.shared

        // Rebuild the status menu when the language changes.
        context.settings.$settings
            .map { $0.general.language }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildStatusMenu() }
            .store(in: &cancellables)

        rebuildStatusMenu()
        Log.switcher.info("App finished launching")

        #if DEBUG
        if SelfTest.isRequested() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SelfTest.run()
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyCenter.shared.unregisterAll()
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Status item

    private func rebuildStatusMenu() {
        guard let statusItem = statusItem ?? makeStatusItem() else { return }
        self.statusItem = statusItem

        let menu = NSMenu()

        let switchItem = NSMenuItem(title: L10n.menuOpenSwitcher,
                                    action: #selector(openSwitcher(_:)), keyEquivalent: "")
        switchItem.target = self
        menu.addItem(switchItem)

        let settingsItem = NSMenuItem(title: L10n.menuSettings,
                                      action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: L10n.menuAbout,
                                   action: #selector(showAbout(_:)), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.menuQuit,
                                  action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.autoenablesItems = false
        statusItem.menu = menu
        statusMenu = menu
    }

    private func makeStatusItem() -> NSStatusItem? {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else { return item }
        button.image = SakuraStatusIcon.makeImage()
        button.image?.size = NSSize(width: 18, height: 18)
        button.imageScaling = .scaleProportionallyDown
        return item
    }

    // MARK: - Actions

    @objc private func openSwitcher(_ sender: Any?) {
        SwitcherController.shared.toggleGlobal()
    }

    @objc private func openSettings(_ sender: Any?) {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func showAbout(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Sakura Switch",
            .applicationVersion: AppInfo.version,
            .version: AppInfo.build,
            .init(rawValue: "Copyright"): "MIT License — github.com/yueseqaz/sakura-switch",
        ])
    }
}
