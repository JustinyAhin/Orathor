import XCTest

@testable import Orathor

@MainActor
final class TranscriptHistoryTests: XCTestCase {
    func testUnknownEnginesLoadWithStatsAndSurviveSaving() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("transcripts.json")
        let id = UUID()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let original = Data(
            """
            [{"id":"\(id.uuidString)","text":"Preserve this transcript","timestamp":"\(timestamp)",
            "durationSeconds":2.5,"wordCount":3,"audioFileName":"saved.m4a",
            "engine":"phonon","requestedEngine":"future-engine","status":"complete"}]
            """.utf8)
        try original.write(to: url)

        let history = TranscriptHistoryService(storageURL: directory)
        XCTAssertNil(history.loadErrorMessage)
        XCTAssertEqual(history.entries.count, 1)
        let entry = try XCTUnwrap(history.entries.first)
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.text, "Preserve this transcript")
        XCTAssertNil(entry.engine)
        XCTAssertNil(entry.requestedEngine)
        XCTAssertEqual(history.todayEntries.count, 1)
        XCTAssertEqual(history.todayWordCount, 3)
        XCTAssertEqual(history.currentStreak, 1)

        history.add(newEntry())
        let saved = try snapshots(at: url)
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(saved.last, try snapshots(from: original).first)
        XCTAssertEqual(saved.first?.engine, SpeechEngine.apple.rawValue)
        let reloaded = TranscriptHistoryService(storageURL: directory)
        XCTAssertNil(reloaded.loadErrorMessage)
        XCTAssertEqual(reloaded.entries.count, 2)
    }

    func testUnreadableHistoryBlocksWritesAndRecordingDeletion() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("transcripts.json")
        let original = Data("unreadable history".utf8)
        try original.write(to: url)
        let history = TranscriptHistoryService(storageURL: directory)
        let audioURL = history.recordingsDirectory.appendingPathComponent("saved.m4a")
        let audio = Data("saved recording".utf8)
        try audio.write(to: audioURL)

        XCTAssertNotNil(history.loadErrorMessage)
        XCTAssertTrue(history.entries.isEmpty)
        let entry = newEntry(audioFileName: "saved.m4a")
        history.add(entry)
        history.delete(entry)

        XCTAssertTrue(history.entries.isEmpty)
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(try Data(contentsOf: audioURL), audio)
    }

    func testRecoveryCopyPreservesEverySavedRecordAndItsStats() async throws {
        guard let sourcePath = ProcessInfo.processInfo.environment["ORATHOR_HISTORY_RECOVERY_SOURCE"] else {
            throw XCTSkip("Set ORATHOR_HISTORY_RECOVERY_SOURCE to validate a private recovery copy")
        }
        let source = URL(fileURLWithPath: sourcePath)
        let original = try Data(contentsOf: source)
        let expected = try snapshots(from: original)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("transcripts.json")
        try original.write(to: url)

        let history = TranscriptHistoryService(storageURL: directory)
        XCTAssertNil(history.loadErrorMessage)
        XCTAssertEqual(history.entries.count, expected.count)
        XCTAssertEqual(
            history.entries.reduce(0) { $0 + $1.wordCount }, expected.reduce(0) { $0 + $1.wordCount })
        let expectedToday = expected.filter { Calendar.current.isDateInToday($0.timestamp) }
        XCTAssertEqual(history.todayEntries.count, expectedToday.count)
        XCTAssertEqual(history.todayWordCount, expectedToday.reduce(0) { $0 + $1.wordCount })

        history.add(newEntry())
        let saved = try snapshots(at: url)
        // Check all original text, IDs, engine labels, dates, and other metadata without logging private text.
        XCTAssertEqual(saved.count, expected.count + 1)
        XCTAssertTrue(Array(saved.dropFirst()) == expected, "Every original record must survive a save")
        XCTAssertTrue(try Data(contentsOf: source) == original, "The recovery source must remain untouched")
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func newEntry(audioFileName: String? = nil) -> TranscriptEntry {
        TranscriptEntry(
            text: "New Apple transcript",
            timestamp: Date(),
            durationSeconds: 1,
            wordCount: 3,
            targetAppName: nil,
            targetAppBundleID: nil,
            audioFileName: audioFileName,
            engine: .apple,
            requestedEngine: .apple)
    }

    private func snapshots(at url: URL) throws -> [HistorySnapshot] {
        try snapshots(from: Data(contentsOf: url))
    }

    private func snapshots(from data: Data) throws -> [HistorySnapshot] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([HistorySnapshot].self, from: data)
    }
}

private struct HistorySnapshot: Decodable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    let durationSeconds: Double
    let wordCount: Int
    let targetAppName: String?
    let targetAppBundleID: String?
    let audioFileName: String?
    let engine: String?
    let requestedEngine: String?
    let status: String?
    let failureMessage: String?
    let smartFormatted: Bool?
    let rawText: String?
    let formattingModel: String?
}
