import AppKit
import Combine
import SakuraSwitchCore

// MARK: - Tab scaffold

/// Flipped vertical stack so scroll content starts at the top.
final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

/// Base class for settings tabs: scrollable column of cards.
class SettingsTabViewController: NSViewController {
    private let build: () -> [NSView]
    private var buildCancellable: AnyCancellable?

    init(build: @escaping () -> [NSView]) {
        self.build = build
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func loadView() {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = false
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true

        let content = FlippedStackView(views: build())
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = DS.space3
        content.edgeInsets = NSEdgeInsets(top: DS.space4, left: DS.space4, bottom: DS.space4, right: DS.space4)
        content.translatesAutoresizingMaskIntoConstraints = false
        content.setHuggingPriority(.defaultLow, for: .horizontal)

        // Uniform width for every top-level element: cards, notes, titles
        // align on both edges — the "clean grid" look.
        for arranged in content.views {
            arranged.widthAnchor.constraint(equalToConstant: 572).isActive = true
        }

        scroll.documentView = content
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view = scroll

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            content.centerXAnchor.constraint(equalTo: scroll.contentView.centerXAnchor),
            content.widthAnchor.constraint(equalToConstant: 620),
        ])
    }

    /// Rebuild content (used when the language changes).
    func rebuild() {
        guard let scroll = view as? NSScrollView,
              let content = scroll.documentView as? FlippedStackView else { return }
        content.views.forEach { $0.removeFromSuperview() }
        for subview in build() {
            content.addArrangedSubview(subview)
            subview.widthAnchor.constraint(equalToConstant: 572).isActive = true
        }
    }
}

// MARK: - Tab container

/// Toolbar-style tab controller (like native app settings).
final class SettingsTabController: NSTabViewController {
    private var languageToken: AnyCancellable?

    init() {
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        let tabs: [(SettingsTabViewController, String, String)] = [
            (GeneralTabViewController(), L10n.tabGeneral, "gearshape"),
            (HotkeysTabViewController(), L10n.tabHotkeys, "command"),
            (AppearanceTabViewController(), L10n.tabAppearance, "paintbrush"),
            (WindowBehaviorTabViewController(), L10n.tabWindowBehavior, "rectangle.on.rectangle"),
            (ExclusionsTabViewController(), L10n.tabExclusions, "eye.slash"),
            (SearchTabViewController(), L10n.tabSearch, "magnifyingglass"),
            (PermissionsTabViewController(), L10n.tabPermissions, "lock.shield"),
            (AboutTabViewController(), L10n.tabAbout, "info.circle"),
        ]
        for (viewController, _, _) in tabs {
            addChild(viewController)
        }
        for (index, item) in tabViewItems.enumerated() {
            item.label = tabs[index].1
            item.image = NSImage(systemSymbolName: tabs[index].2, accessibilityDescription: tabs[index].1)
        }
        for (viewController, _, _) in tabs {
            viewController.preferredContentSize = NSSize(width: 680, height: 560)
        }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }
}

// MARK: - Window controller

@MainActor
final class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private var languageCancellable: AnyCancellable?

    private convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 560),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = L10n.settingsTitle
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.contentViewController = SettingsTabController()
        self.init(window: window)

        // Rebuild tab labels when the language changes.
        languageCancellable = AppContext.shared.settings.$settings
            .map { $0.general.language }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let tabController = self.window?.contentViewController as? SettingsTabController else { return }
                self.window?.title = L10n.settingsTitle
                let titles = [L10n.tabGeneral, L10n.tabHotkeys, L10n.tabAppearance, L10n.tabWindowBehavior,
                              L10n.tabExclusions, L10n.tabSearch, L10n.tabPermissions, L10n.tabAbout]
                for (index, item) in tabController.tabViewItems.enumerated() where index < titles.count {
                    item.label = titles[index]
                }
                for case let vc as SettingsTabViewController in tabController.children {
                    vc.rebuild()
                }
            }
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
