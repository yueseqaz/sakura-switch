import AppKit
import SakuraSwitchCore

/// Search settings: fuzzy matching and persistent search memory.
final class SearchTabViewController: SettingsTabViewController {

    init() {
        super.init { Self.buildContent() }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    private static func buildContent() -> [NSView] {
        let context = AppContext.shared
        let search = context.settings.current.search
        let memoryStore = context.searchMemory

        func switchRow(title: String,
                       hint: String,
                       isOn: Bool,
                       keyPath: @escaping (inout AppSettings.Search, Bool) -> Void) -> NSView {
            let toggle = ClosureSwitch(isOn: isOn) { on in
                context.settings.update { keyPath(&$0.search, on) }
            }
            toggle.setAccessibilityLabel(title)
            return DSForm.row(title: title, hint: hint, control: toggle)
        }

        let fuzzyRow = switchRow(title: L10n.searchFuzzy,
                                 hint: L10n.searchFuzzyHint,
                                 isOn: search.fuzzyEnabled) { $0.fuzzyEnabled = $1 }
        let memoryRow = switchRow(title: L10n.searchMemory,
                                  hint: L10n.searchMemoryHint,
                                  isOn: search.memoryEnabled) { $0.memoryEnabled = $1 }

        // Clear memory row with a live count.
        let countLabel = makeLabel(memoryDetail(store: memoryStore), font: DS.fontCaption, color: DS.textSecondary)
        let clearedNote = DSForm.note(L10n.searchMemoryCleared, tone: .info)
        clearedNote.isHidden = true

        var clearButtonRef: DSButton?
        let clearButton = DSButton(L10n.searchClearMemory) {
            memoryStore.clear()
            countLabel.stringValue = memoryDetail(store: memoryStore)
            clearButtonRef?.isEnabled = !memoryStore.memory.map.isEmpty
            clearedNote.isHidden = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                clearedNote.isHidden = true
            }
        }
        clearButtonRef = clearButton
        clearButton.isEnabled = !memoryStore.memory.map.isEmpty

        let textStack = NSStackView(views: [
            makeLabel(L10n.searchClearMemory, font: DS.fontBody, color: DS.textPrimary),
            countLabel,
        ])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let clearRow = NSStackView(views: [textStack, clearButton])
        clearRow.orientation = .horizontal
        clearRow.alignment = .centerY
        clearRow.spacing = DS.space2
        clearRow.edgeInsets = NSEdgeInsets(top: 11, left: DS.space3, bottom: 11, right: DS.space3)
        clearRow.translatesAutoresizingMaskIntoConstraints = false

        let clearCard = DSCardView()
        let clearInner = NSStackView(views: [clearRow])
        clearInner.orientation = .vertical
        clearInner.alignment = .leading
        clearInner.spacing = 0
        clearInner.translatesAutoresizingMaskIntoConstraints = false
        clearCard.addSubview(clearInner)
        NSLayoutConstraint.activate([
            clearInner.topAnchor.constraint(equalTo: clearCard.topAnchor),
            clearInner.bottomAnchor.constraint(equalTo: clearCard.bottomAnchor),
            clearInner.leadingAnchor.constraint(equalTo: clearCard.leadingAnchor),
            clearInner.trailingAnchor.constraint(equalTo: clearCard.trailingAnchor),
        ])

        let clearStack = NSStackView(views: [clearCard])
        clearStack.orientation = .vertical
        clearStack.alignment = .leading
        clearStack.spacing = DS.space2
        clearStack.addArrangedSubview(clearedNote)
        clearStack.translatesAutoresizingMaskIntoConstraints = false
        clearedNote.widthAnchor.constraint(equalTo: clearCard.widthAnchor).isActive = true

        return [
            makeLabel(L10n.tabSearch, font: DS.fontTitle, color: DS.textPrimary),
            DSForm.card(rows: [fuzzyRow, DSForm.divider(), memoryRow]),
            clearStack,
        ]
    }

    private static func memoryDetail(store: SearchMemoryStore) -> String {
        let count = store.memory.map.count
        return L10n.isChinese
            ? "当前记住 \(count) 条缩写"
            : "\(count) abbreviation\(count == 1 ? "" : "s") remembered"
    }
}
