import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PersonalDictionarySettingsView: View {
    @Bindable var dictionary: PersonalDictionaryService
    @Bindable var settings: SettingsViewModel

    @State private var newTerm = ""
    @State private var newSource = ""
    @State private var newReplacement = ""
    @State private var editingTermID: UUID?
    @State private var editingTermValue = ""
    @State private var editingRuleID: UUID?
    @State private var editingSource = ""
    @State private var editingReplacement = ""
    @State private var actionError: String?

    private var sharedTermCount: Int {
        settings.cloudVocabularyEnabled
            ? min(dictionary.terms.count, PersonalDictionarySnapshot.cloudHintLimit)
            : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ContentSectionHeader(
                title: "Personal dictionary",
                symbol: "character.book.closed",
                meta: dictionary.terms.isEmpty && dictionary.replacements.isEmpty
                    ? nil
                    : "\(dictionary.terms.count) terms · \(dictionary.replacements.count) rules"
            )

            vocabularyCard
            replacementsCard

            if let loadError = dictionary.loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .font(OType.caption)
                    .foregroundStyle(Color.warning)
            }
        }
        .alert("Personal dictionary", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "Unknown error")
        }
    }

    private var vocabularyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(
                "Vocabulary",
                caption: "Exact spelling for names, products, acronyms, and technical terms"
            )

            SubtleDivider()
            cloudSharingRow

            ForEach(Array(dictionary.terms.enumerated()), id: \.element.id) { index, term in
                SubtleDivider()
                termRow(term, index: index)
            }

            SubtleDivider()
            HStack(spacing: Spacing.sm) {
                TextField("Add a term, e.g. Orathor", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTerm)
                Button("Add", action: addTerm)
                    .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            if dictionary.terms.count > PersonalDictionarySnapshot.cloudHintLimit {
                Label(
                    "Cloud engines use the first \(PersonalDictionarySnapshot.cloudHintLimit) terms shown. Reorder terms to choose which are shared.",
                    systemImage: "info.circle"
                )
                .font(OType.caption)
                .foregroundStyle(Color.warning)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
            }

            if settings.selectedEngine == .openAIWhisper, openAIIncompatibleCount > 0 {
                Label(
                    "\(openAIIncompatibleCount) terms containing angle brackets stay local because OpenAI does not accept them as hints.",
                    systemImage: "info.circle"
                )
                .font(OType.caption)
                .foregroundStyle(Color.warning)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
            }
        }
        .cardStyle(padding: 0)
    }

    private var replacementsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(
                "Replacement rules",
                caption: "Exact local corrections run after every transcription"
            )

            ForEach(dictionary.replacements) { rule in
                SubtleDivider()
                replacementRow(rule)
            }

            SubtleDivider()
            HStack(spacing: Spacing.sm) {
                TextField("Heard text", text: $newSource)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                TextField("Write as", text: $newReplacement)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addReplacement)
                Button("Add", action: addReplacement)
                    .disabled(
                        newSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || newReplacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            SubtleDivider()
            Button(action: exportDictionary) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export dictionary")
                            .font(OType.body)
                            .foregroundStyle(Color.textPrimary)
                        Text("Save a support-friendly JSON copy; API keys and transcripts are excluded")
                            .font(OType.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .cardStyle(padding: 0)
    }

    private var cloudSharingRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Use vocabulary with cloud engines")
                    .font(OType.body)
                    .foregroundStyle(Color.textPrimary)
                Text(settings.cloudVocabularyEnabled
                    ? "\(sharedTermCount) terms shared only while using OpenAI or Deepgram"
                    : "Terms stay on this Mac and still apply locally")
                    .font(OType.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $settings.cloudVocabularyEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    @ViewBuilder
    private func termRow(_ term: PersonalDictionaryTerm, index: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            if editingTermID == term.id {
                TextField("Vocabulary term", text: $editingTermValue)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveTermEdit)
                rowButton("checkmark", help: "Save", action: saveTermEdit)
                rowButton("xmark", help: "Cancel") { editingTermID = nil }
            } else {
                Text(term.value)
                    .font(OType.body)
                    .foregroundStyle(Color.textPrimary)
                    .textSelection(.enabled)
                Spacer()
                rowButton("arrow.up", help: "Move up") {
                    perform { try dictionary.moveTerm(id: term.id, offset: -1) }
                }
                .disabled(index == 0)
                rowButton("arrow.down", help: "Move down") {
                    perform { try dictionary.moveTerm(id: term.id, offset: 1) }
                }
                .disabled(index == dictionary.terms.count - 1)
                rowButton("pencil", help: "Edit") {
                    editingTermID = term.id
                    editingTermValue = term.value
                }
                rowButton("trash", help: "Delete") {
                    perform { try dictionary.deleteTerm(id: term.id) }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func replacementRow(_ rule: ReplacementRule) -> some View {
        HStack(spacing: Spacing.sm) {
            if editingRuleID == rule.id {
                TextField("Heard text", text: $editingSource)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                TextField("Write as", text: $editingReplacement)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveReplacementEdit)
                rowButton("checkmark", help: "Save", action: saveReplacementEdit)
                rowButton("xmark", help: "Cancel") { editingRuleID = nil }
            } else {
                Text(rule.source)
                    .font(OType.body)
                    .foregroundStyle(Color.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Text(rule.replacement)
                    .font(OType.body)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                rowButton("pencil", help: "Edit") {
                    editingRuleID = rule.id
                    editingSource = rule.source
                    editingReplacement = rule.replacement
                }
                rowButton("trash", help: "Delete") {
                    perform { try dictionary.deleteReplacement(id: rule.id) }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func sectionTitle(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(OType.body)
                .foregroundStyle(Color.textPrimary)
            Text(caption)
                .font(OType.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var openAIIncompatibleCount: Int {
        dictionary.terms.prefix(PersonalDictionarySnapshot.cloudHintLimit).count {
            $0.value.contains("<") || $0.value.contains(">")
        }
    }

    private func rowButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.textTertiary)
        .help(help)
    }

    private func addTerm() {
        perform {
            try dictionary.addTerm(newTerm)
            newTerm = ""
        }
    }

    private func saveTermEdit() {
        guard let editingTermID else { return }
        perform {
            try dictionary.updateTerm(id: editingTermID, value: editingTermValue)
            self.editingTermID = nil
        }
    }

    private func addReplacement() {
        perform {
            try dictionary.addReplacement(source: newSource, replacement: newReplacement)
            newSource = ""
            newReplacement = ""
        }
    }

    private func saveReplacementEdit() {
        guard let editingRuleID else { return }
        perform {
            try dictionary.updateReplacement(
                id: editingRuleID,
                source: editingSource,
                replacement: editingReplacement
            )
            self.editingRuleID = nil
        }
    }

    private func exportDictionary() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "orathor-personal-dictionary.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform {
            let data = try dictionary.exportData(
                cloudHintsEnabled: settings.cloudVocabularyEnabled)
            try data.write(to: url, options: .atomic)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
