import AppKit
import SakuraSwitchCore

/// Exclusions: bundle IDs never shown in the switcher. In-place add/remove.
final class ExclusionsTabViewController: SettingsTabViewController {

    init() {
        super.init { Self.buildContent() }
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    private static func buildContent() -> [NSView] {
        let context = AppContext.shared
        var draft = ""
        var errorNote: NSView?

        let errorContainer = NSStackView(views: [])
        errorContainer.orientation = .vertical
        errorContainer.alignment = .leading
        errorContainer.spacing = 0
        errorContainer.translatesAutoresizingMaskIntoConstraints = false

        func showError(_ text: String) {
            errorContainer.views.forEach { $0.removeFromSuperview() }
            errorNote = DSForm.note(text, tone: .error)
            errorContainer.addArrangedSubview(errorNote!)
        }

        func hideError() {
            errorContainer.views.forEach { $0.removeFromSuperview() }
        }

        // Input field
        let field = NSTextField(string: "")
        field.placeholderString = L10n.exclusionsAddPlaceholder
        field.font = DS.fontBody
        field.isBordered = false
        field.focusRingType = .none
        field.backgroundColor = .clear
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = FieldDelegate.shared

        let addButton = DSButton(L10n.exclusionsAdd) {
            let candidate = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard WindowExclusions.isValid(bundleID: candidate) else {
                showError(L10n.exclusionsInvalid)
                return
            }
            guard !context.settings.current.excludedBundleIDs.contains(candidate) else {
                showError(L10n.exclusionsDuplicate)
                return
            }
            hideError()
            context.settings.update { $0.excludedBundleIDs.append(candidate) }
            field.stringValue = ""
            draft = ""
        }
        addButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        let addRow = NSStackView(views: [field, addButton])
        addRow.orientation = .horizontal
        addRow.alignment = .centerY
        addRow.spacing = DS.space1
        addRow.edgeInsets = NSEdgeInsets(top: DS.space1, left: DS.space2, bottom: DS.space1, right: DS.space2)
        addRow.translatesAutoresizingMaskIntoConstraints = false

        FieldDelegate.shared.onSubmit[ObjectIdentifier(field)] = {
            addButton.performClick(nil)
        }
        FieldDelegate.shared.onChange[ObjectIdentifier(field)] = { value in
            draft = value
        }

        // List of current exclusions
        let listStack = NSStackView(views: [])
        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 0
        listStack.translatesAutoresizingMaskIntoConstraints = false

        func rebuildList() {
            listStack.views.forEach { $0.removeFromSuperview() }
            let exclusions = context.settings.current.excludedBundleIDs
            if exclusions.isEmpty {
                let empty = makeLabel(L10n.exclusionsEmpty, font: DS.fontBody, color: DS.textTertiary)
                empty.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                let row = NSStackView(views: [empty])
                row.edgeInsets = NSEdgeInsets(top: DS.space2, left: DS.space2, bottom: DS.space2, right: DS.space2)
                listStack.addArrangedSubview(row)
            } else {
                for (index, bundleID) in exclusions.enumerated() {
                    if index > 0 {
                        let divider = DSForm.divider(leadingInset: DS.space2)
                        divider.widthAnchor.constraint(equalToConstant: 572 - DS.space4).isActive = true
                        listStack.addArrangedSubview(divider)
                    }
                    let icon = NSImageView(image: NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)!)
                    icon.contentTintColor = DS.textTertiary
                    icon.setContentCompressionResistancePriority(.required, for: .horizontal)

                    let label = makeLabel(bundleID, font: DS.fontMono, color: DS.textPrimary)
                    label.lineBreakMode = .byTruncatingMiddle
                    label.setContentHuggingPriority(.defaultLow, for: .horizontal)

                    let removeButton = DSButton(L10n.exclusionsRemove, kind: .ghost) {
                        context.settings.update {
                            $0.excludedBundleIDs.removeAll { $0 == bundleID }
                        }
                        rebuildList()
                    }

                    let row = NSStackView(views: [icon, label, NSView(), removeButton])
                    row.orientation = .horizontal
                    row.alignment = .centerY
                    row.spacing = DS.space1
                    row.edgeInsets = NSEdgeInsets(top: 7, left: DS.space2, bottom: 7, right: DS.space2)
                    row.translatesAutoresizingMaskIntoConstraints = false
                    row.widthAnchor.constraint(equalToConstant: 572 - DS.space4).isActive = true
                    // Make the spacer stretch.
                    row.arrangedSubviews[2].setContentHuggingPriority(.defaultLow, for: .horizontal)
                    listStack.addArrangedSubview(row)
                }
            }
        }
        rebuildList()

        let card = DSCardView()
        let inner = NSStackView(views: [addRow, DSForm.divider(leadingInset: 0), listStack])
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        ])

        return [
            makeLabel(L10n.tabExclusions, font: DS.fontTitle, color: DS.textPrimary),
            makeLabel(L10n.exclusionsHint, font: DS.fontBody, color: DS.textSecondary),
            card,
            errorContainer,
        ]
    }
}

/// Shared NSTextFieldDelegate bridge for form fields.
final class FieldDelegate: NSObject, NSTextFieldDelegate {
    static let shared = FieldDelegate()
    var onSubmit: [ObjectIdentifier: () -> Void] = [:]
    var onChange: [ObjectIdentifier: (String) -> Void] = [:]

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
              let handler = onChange[ObjectIdentifier(field)] else { return }
        handler(field.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let field = control as? NSTextField, let handler = onSubmit[ObjectIdentifier(field)] else {
            return false
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            handler()
            return true
        }
        return false
    }
}
