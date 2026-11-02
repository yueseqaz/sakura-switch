import AppKit
import Combine
import Carbon.HIToolbox
import SakuraSwitchCore

/// Hotkey recorder: click, press the new combination, done.
/// Esc cancels; modifier-only presses wait; plain keys are rejected.
final class KeyRecorderButton: DSButton {
    private var monitor: Any?
    private(set) var isRecording = false
    var onFinish: (KeyCombo) -> Void = { _ in }
    var onError: (String) -> Void = { _ in }

    private var combo: KeyCombo

    init(combo: KeyCombo) {
        self.combo = combo
        super.init(combo.displayString.isEmpty ? "…" : combo.displayString, kind: .neutral, action: { })
        // Replace the no-op action: DSButton routes clicks to `action`, but we
        // need instance behavior — use target/action instead.
        target = self
        action = #selector(toggleRecording)
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    func update(combo newCombo: KeyCombo) {
        combo = newCombo
        if !isRecording {
            title = newCombo.displayString
            refreshAttributedTitle()
        }
    }

    @objc private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        title = L10n.hotkeyRecording
        refreshAttributedTitle()

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            switch event.type {
            case .flagsChanged:
                return nil // wait for the full combination
            case .keyDown:
                let modifiers = KeyCombo.carbonModifiers(from: event.modifierFlags)
                if event.keyCode == UInt16(kVK_Escape) && modifiers == 0 {
                    DispatchQueue.main.async { self.stopRecording() }
                    return nil
                }
                guard modifiers != 0 else {
                    DispatchQueue.main.async {
                        self.onError(L10n.hotkeyNeedsModifier)
                        self.stopRecording()
                    }
                    return nil
                }
                let newCombo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
                DispatchQueue.main.async {
                    self.stopRecording()
                    self.combo = newCombo
                    self.title = newCombo.displayString
                    self.refreshAttributedTitle()
                    self.onFinish(newCombo)
                }
                return nil
            default:
                return event
            }
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
        title = combo.displayString
        refreshAttributedTitle()
    }

    private func refreshAttributedTitle() {
        if isRecording {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: DS.fontCaptionMedium,
                .foregroundColor: DS.textSecondary,
            ]
            attributedTitle = NSAttributedString(string: L10n.hotkeyRecording, attributes: attributes)
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: DS.fontCaptionMedium,
                .foregroundColor: DS.textPrimary,
            ]
            attributedTitle = NSAttributedString(string: combo.displayString, attributes: attributes)
        }
    }
}

/// Hotkeys: the two global shortcuts with in-place recording.
final class HotkeysTabViewController: SettingsTabViewController {

    init() {
        super.init { Self.buildContent() }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    private static func buildContent() -> [NSView] {
        let context = AppContext.shared
        let coordinator = context.hotkeys

        let globalRecorder = KeyRecorderButton(combo: context.settings.current.hotkeys.globalSwitch)
        let inAppRecorder = KeyRecorderButton(combo: context.settings.current.hotkeys.inAppSwitch)

        let globalError = DSForm.note(L10n.hotkeyConflict, tone: .error)
        globalError.isHidden = true
        let inAppError = DSForm.note(L10n.hotkeyConflict, tone: .error)
        inAppError.isHidden = true

        func updateGlobal(_ newCombo: KeyCombo) {
            context.settings.update { $0.hotkeys.globalSwitch = newCombo }
            globalError.isHidden = !coordinator.isFailed(HotkeyCoordinator.globalID)
        }
        func updateInApp(_ newCombo: KeyCombo) {
            context.settings.update { $0.hotkeys.inAppSwitch = newCombo }
            inAppError.isHidden = !coordinator.isFailed(HotkeyCoordinator.inAppID)
        }

        globalRecorder.onFinish = updateGlobal
        globalRecorder.onError = { _ in }
        inAppRecorder.onFinish = updateInApp
        inAppRecorder.onError = { _ in }

        let globalRow = rowWith(title: L10n.hotkeyGlobal,
                                hint: L10n.hotkeyGlobalHint,
                                control: globalRecorder,
                                error: globalError)
        let inAppRow = rowWith(title: L10n.hotkeyInApp,
                               hint: L10n.hotkeyInAppHint,
                               control: inAppRecorder,
                               error: inAppError)

        let hint = DSForm.note(L10n.hotkeyHintRelease, tone: .info)

        let releaseBehavior = context.settings.current.hotkeys.releaseBehavior
        let releaseOptions = AppSettings.Hotkeys.ReleaseBehavior.allCases
        let releaseControl = ClosureSegmented(labels: [L10n.hotkeyReleaseSwitchAndClose, L10n.hotkeyReleaseKeepOpen],
                                              selectedIndex: releaseOptions.firstIndex(of: releaseBehavior) ?? 0) { index in
            guard releaseOptions.indices.contains(index) else { return }
            context.settings.update { $0.hotkeys.releaseBehavior = releaseOptions[index] }
        }
        releaseControl.setAccessibilityLabel(L10n.hotkeyReleaseBehavior)
        releaseControl.widthAnchor.constraint(equalToConstant: 250).isActive = true
        let releaseRow = DSForm.row(title: L10n.hotkeyReleaseBehavior, control: releaseControl)

        let resetButton = DSButton(L10n.hotkeyResetDefaults) {
            context.settings.resetHotkeysToDefaults()
            globalRecorder.update(combo: context.settings.current.hotkeys.globalSwitch)
            inAppRecorder.update(combo: context.settings.current.hotkeys.inAppSwitch)
            releaseControl.selectedSegment = releaseOptions.firstIndex(of: context.settings.current.hotkeys.releaseBehavior) ?? 0
            globalError.isHidden = !coordinator.isFailed(HotkeyCoordinator.globalID)
            inAppError.isHidden = !coordinator.isFailed(HotkeyCoordinator.inAppID)
        }
        let resetRow = rightAlignedRow(resetButton)

        return [
            makeLabel(L10n.tabHotkeys, font: DS.fontTitle, color: DS.textPrimary),
            DSForm.card(rows: [globalRow, DSForm.divider(), inAppRow, DSForm.divider(), releaseRow]),
            hint,
            resetRow,
        ]
    }

    /// Full-width row with its content pushed to the trailing edge.
    private static func rightAlignedRow(_ view: NSView) -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [spacer, view])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = DS.space2
        row.edgeInsets = NSEdgeInsets(top: 4, left: DS.space3, bottom: 4, right: DS.space3)
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private static func rowWith(title: String, hint: String, control: NSButton, error: NSView) -> NSView {
        let textStack = NSStackView(views: [
            makeLabel(title, font: DS.fontBody, color: DS.textPrimary),
            makeLabel(hint, font: DS.fontCaption, color: DS.textSecondary),
        ])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let top = NSStackView(views: [textStack, control])
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = DS.space2
        top.edgeInsets = NSEdgeInsets(top: 11, left: DS.space3, bottom: 11, right: DS.space3)
        top.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView(views: [top])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = DS.space1
        container.addArrangedSubview(error)
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }
}
