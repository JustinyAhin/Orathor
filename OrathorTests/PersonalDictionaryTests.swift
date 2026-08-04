import XCTest

@testable import Orathor

@MainActor
final class PersonalDictionaryTests: XCTestCase {
    func testStoreNormalizesPersistsReordersAndValidatesDuplicates() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("personal-dictionary.json")
        let service = PersonalDictionaryService(storageURL: url)

        try service.addTerm("  Orathor  ")
        try service.addTerm("Swift   Concurrency")
        try service.addReplacement(source: "  orator ", replacement: " Orathor ")

        XCTAssertThrowsError(try service.addTerm("orathor")) { error in
            XCTAssertEqual(error as? PersonalDictionaryService.ValidationError, .duplicateTerm)
        }
        XCTAssertThrowsError(try service.addReplacement(source: "ORATOR", replacement: "Other")) { error in
            XCTAssertEqual(error as? PersonalDictionaryService.ValidationError, .duplicateReplacement)
        }

        try service.moveTerm(id: service.terms[1].id, offset: -1)
        let reloaded = PersonalDictionaryService(storageURL: url)
        XCTAssertEqual(reloaded.terms.map(\.value), ["Swift Concurrency", "Orathor"])
        XCTAssertEqual(reloaded.replacements.first?.source, "orator")
        XCTAssertEqual(reloaded.replacements.first?.replacement, "Orathor")
    }

    func testCloudSnapshotCapsTermsAndCanStayLocal() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = PersonalDictionaryService(
            storageURL: directory.appendingPathComponent("dictionary.json"))

        for index in 0...PersonalDictionarySnapshot.cloudHintLimit {
            try service.addTerm("Term \(index)")
        }

        XCTAssertEqual(
            service.snapshot(cloudHintsEnabled: true).cloudKeywords.count,
            PersonalDictionarySnapshot.cloudHintLimit)
        XCTAssertTrue(service.snapshot(cloudHintsEnabled: false).cloudKeywords.isEmpty)
        XCTAssertEqual(service.snapshot(cloudHintsEnabled: false).terms.count, 101)
    }

    func testCorruptFileIsPreservedAndReported() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("dictionary.json")
        let original = Data("not json".utf8)
        try original.write(to: url)

        let service = PersonalDictionaryService(storageURL: url)

        XCTAssertNotNil(service.loadError)
        XCTAssertTrue(service.terms.isEmpty)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testFailedSaveRollsBackMutation() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileWhereDirectoryIsExpected = directory.appendingPathComponent("blocked")
        try Data("file".utf8).write(to: fileWhereDirectoryIsExpected)
        let service = PersonalDictionaryService(
            storageURL: fileWhereDirectoryIsExpected.appendingPathComponent("dictionary.json"))

        XCTAssertThrowsError(try service.addTerm("Orathor"))
        XCTAssertTrue(service.terms.isEmpty)
    }

    func testExportIncludesDictionaryAndPrivacyPreference() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = PersonalDictionaryService(
            storageURL: directory.appendingPathComponent("dictionary.json"))
        try service.addTerm("Orathor")
        try service.addReplacement(source: "orator", replacement: "Orathor")

        let data = try service.exportData(
            cloudHintsEnabled: false,
            date: Date(timeIntervalSince1970: 100))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(PersonalDictionaryExport.self, from: data)

        XCTAssertEqual(export.schemaVersion, PersonalDictionaryDocument.currentSchemaVersion)
        XCTAssertFalse(export.cloudHintsEnabled)
        XCTAssertEqual(export.terms.map(\.value), ["Orathor"])
        XCTAssertEqual(export.replacements.first?.source, "orator")
    }

    func testPersonalizerUsesBoundariesLongestMatchAndCanonicalCapitalization() {
        let snapshot = PersonalDictionarySnapshot(
            terms: ["Orathor", "C++"],
            replacements: [
                ReplacementRule(source: "orator", replacement: "Orathor"),
                ReplacementRule(source: "new", replacement: "old"),
                ReplacementRule(source: "new york", replacement: "NYC"),
            ],
            cloudKeywords: [])

        let result = TranscriptPersonalizer().personalize(
            "orator and orathor use c++ in New York, but newly stays.",
            using: snapshot)

        XCTAssertEqual(result, "Orathor and Orathor use C++ in NYC, but newly stays.")
    }

    func testPersonalizerIsSinglePassAndNonCascading() {
        let snapshot = PersonalDictionarySnapshot(
            terms: [],
            replacements: [
                ReplacementRule(source: "foo", replacement: "bar"),
                ReplacementRule(source: "bar", replacement: "baz"),
            ],
            cloudKeywords: [])

        XCTAssertEqual(
            TranscriptPersonalizer().personalize("foo bar", using: snapshot),
            "bar baz")
    }

    func testFormattingInstructionsContainTermsRulesAndAntiHallucinationGuard() {
        let snapshot = PersonalDictionarySnapshot(
            terms: ["Orathor"],
            replacements: [ReplacementRule(source: "orator", replacement: "Orathor")],
            cloudKeywords: [])

        let instructions = TranscriptPolisher.instructions(for: snapshot)
        XCTAssertTrue(instructions.contains("Orathor"))
        XCTAssertTrue(instructions.contains("orator → Orathor"))
        XCTAssertTrue(instructions.contains("Never add a term unless the speaker said it"))
    }

    func testDeepgramURLRepeatsAndEncodesKeyterms() throws {
        let url = try DeepgramService.connectionURL(
            language: "en",
            keywords: ["Orathor", "Swift Concurrency"])
        let items = try XCTUnwrap(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        XCTAssertEqual(items.filter { $0.name == "keyterm" }.compactMap(\.value), [
            "Orathor", "Swift Concurrency",
        ])
        XCTAssertEqual(items.first(where: { $0.name == "model" })?.value, "nova-3")
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrathorTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
