import Foundation

nonisolated struct PersonalDictionaryTerm: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var value: String

    init(id: UUID = UUID(), value: String) {
        self.id = id
        self.value = value
    }
}

nonisolated struct ReplacementRule: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var source: String
    var replacement: String

    init(id: UUID = UUID(), source: String, replacement: String) {
        self.id = id
        self.source = source
        self.replacement = replacement
    }
}

nonisolated struct PersonalDictionarySnapshot: Equatable, Hashable, Sendable {
    static let cloudHintLimit = 100
    static let empty = PersonalDictionarySnapshot(terms: [], replacements: [], cloudKeywords: [])

    let terms: [String]
    let replacements: [ReplacementRule]
    let cloudKeywords: [String]

    var formattingInstructions: String? {
        guard !terms.isEmpty || !replacements.isEmpty else { return nil }

        var sections: [String] = []
        if !terms.isEmpty {
            sections.append("Preserve the exact spelling and capitalization of these terms when they are spoken:\n"
                + terms.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !replacements.isEmpty {
            sections.append("Honor these exact dictated-text replacements without changing unrelated wording:\n"
                + replacements.map { "- \($0.source) → \($0.replacement)" }.joined(separator: "\n"))
        }
        sections.append("These are hints only. Never add a term unless the speaker said it.")
        return sections.joined(separator: "\n\n")
    }
}

nonisolated struct PersonalDictionaryDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var terms: [PersonalDictionaryTerm]
    var replacements: [ReplacementRule]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        terms: [PersonalDictionaryTerm] = [],
        replacements: [ReplacementRule] = []
    ) {
        self.schemaVersion = schemaVersion
        self.terms = terms
        self.replacements = replacements
    }
}

nonisolated struct PersonalDictionaryExport: Codable, Sendable {
    let schemaVersion: Int
    let exportedAt: Date
    let cloudHintsEnabled: Bool
    let terms: [PersonalDictionaryTerm]
    let replacements: [ReplacementRule]
}
