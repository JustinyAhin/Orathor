import Foundation
import os

private let dictionaryLogger = Logger(
    subsystem: AppDistribution.storageIdentifier,
    category: "PersonalDictionary"
)

@Observable
nonisolated final class PersonalDictionaryService {
    enum ValidationError: LocalizedError, Equatable {
        case emptyTerm
        case duplicateTerm
        case emptyReplacement
        case duplicateReplacement

        var errorDescription: String? {
            switch self {
            case .emptyTerm: "Enter a vocabulary term."
            case .duplicateTerm: "That vocabulary term already exists."
            case .emptyReplacement: "Enter both the heard text and its replacement."
            case .duplicateReplacement: "A rule for that heard text already exists."
            }
        }
    }

    private(set) var terms: [PersonalDictionaryTerm] = []
    private(set) var replacements: [ReplacementRule] = []
    private(set) var loadError: String?

    private let storageURL: URL
    private let fileManager: FileManager

    init(storageURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageURL = appSupport
                .appendingPathComponent(AppDistribution.storageIdentifier, isDirectory: true)
                .appendingPathComponent("personal-dictionary.json")
        }
        let shouldLoad = storageURL != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        if shouldLoad { load() }
    }

    func snapshot(cloudHintsEnabled: Bool) -> PersonalDictionarySnapshot {
        let values = terms.map(\.value)
        return PersonalDictionarySnapshot(
            terms: values,
            replacements: replacements,
            cloudKeywords: cloudHintsEnabled
                ? Array(values.prefix(PersonalDictionarySnapshot.cloudHintLimit))
                : []
        )
    }

    func addTerm(_ value: String) throws {
        let normalized = Self.normalize(value)
        guard !normalized.isEmpty else { throw ValidationError.emptyTerm }
        guard !terms.contains(where: { Self.key($0.value) == Self.key(normalized) }) else {
            throw ValidationError.duplicateTerm
        }
        let term = PersonalDictionaryTerm(value: normalized)
        terms.append(term)
        do {
            try save()
        } catch {
            terms.removeAll { $0.id == term.id }
            throw error
        }
    }

    func updateTerm(id: UUID, value: String) throws {
        let normalized = Self.normalize(value)
        guard !normalized.isEmpty else { throw ValidationError.emptyTerm }
        guard !terms.contains(where: { $0.id != id && Self.key($0.value) == Self.key(normalized) }) else {
            throw ValidationError.duplicateTerm
        }
        guard let index = terms.firstIndex(where: { $0.id == id }) else { return }
        let previous = terms[index]
        terms[index].value = normalized
        do {
            try save()
        } catch {
            terms[index] = previous
            throw error
        }
    }

    func deleteTerm(id: UUID) throws {
        guard let index = terms.firstIndex(where: { $0.id == id }) else { return }
        let removed = terms.remove(at: index)
        do {
            try save()
        } catch {
            terms.insert(removed, at: index)
            throw error
        }
    }

    func moveTerm(id: UUID, offset: Int) throws {
        guard let source = terms.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard terms.indices.contains(destination) else { return }
        terms.swapAt(source, destination)
        do {
            try save()
        } catch {
            terms.swapAt(source, destination)
            throw error
        }
    }

    func addReplacement(source: String, replacement: String) throws {
        let source = Self.normalize(source)
        let replacement = Self.normalize(replacement)
        guard !source.isEmpty, !replacement.isEmpty else { throw ValidationError.emptyReplacement }
        guard !replacements.contains(where: { Self.key($0.source) == Self.key(source) }) else {
            throw ValidationError.duplicateReplacement
        }
        let rule = ReplacementRule(source: source, replacement: replacement)
        replacements.append(rule)
        do {
            try save()
        } catch {
            replacements.removeAll { $0.id == rule.id }
            throw error
        }
    }

    func updateReplacement(id: UUID, source: String, replacement: String) throws {
        let source = Self.normalize(source)
        let replacement = Self.normalize(replacement)
        guard !source.isEmpty, !replacement.isEmpty else { throw ValidationError.emptyReplacement }
        guard !replacements.contains(where: { $0.id != id && Self.key($0.source) == Self.key(source) }) else {
            throw ValidationError.duplicateReplacement
        }
        guard let index = replacements.firstIndex(where: { $0.id == id }) else { return }
        let previous = replacements[index]
        replacements[index].source = source
        replacements[index].replacement = replacement
        do {
            try save()
        } catch {
            replacements[index] = previous
            throw error
        }
    }

    func deleteReplacement(id: UUID) throws {
        guard let index = replacements.firstIndex(where: { $0.id == id }) else { return }
        let removed = replacements.remove(at: index)
        do {
            try save()
        } catch {
            replacements.insert(removed, at: index)
            throw error
        }
    }

    func exportData(cloudHintsEnabled: Bool, date: Date = Date()) throws -> Data {
        let export = PersonalDictionaryExport(
            schemaVersion: PersonalDictionaryDocument.currentSchemaVersion,
            exportedAt: date,
            cloudHintsEnabled: cloudHintsEnabled,
            terms: terms,
            replacements: replacements
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    private func load() {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let document = try JSONDecoder().decode(PersonalDictionaryDocument.self, from: data)
            guard document.schemaVersion == PersonalDictionaryDocument.currentSchemaVersion else {
                throw CocoaError(.fileReadCorruptFile)
            }
            terms = document.terms
            replacements = document.replacements
        } catch {
            loadError = "The personal dictionary could not be loaded. Your existing file was left unchanged."
            dictionaryLogger.error("Dictionary load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() throws {
        let directory = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let document = PersonalDictionaryDocument(terms: terms, replacements: replacements)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: storageURL, options: .atomic)
        loadError = nil
    }

    private static func normalize(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func key(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
