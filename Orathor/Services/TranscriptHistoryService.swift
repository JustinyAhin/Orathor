import Foundation
import os

private let logger = Logger(subsystem: "segbedji.Orathor", category: "TranscriptHistory")

@Observable
final class TranscriptHistoryService {
    private(set) var entries: [TranscriptEntry] = []

    private let storageURL: URL
    private let recordingsURL: URL
    private let transcriptsFileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = appSupport.appendingPathComponent("segbedji.Orathor", isDirectory: true)
        recordingsURL = storageURL.appendingPathComponent("Recordings", isDirectory: true)
        transcriptsFileURL = storageURL.appendingPathComponent("transcripts.json")

        createDirectoriesIfNeeded()
        loadEntries()
    }

    var recordingsDirectory: URL { recordingsURL }

    func add(_ entry: TranscriptEntry) {
        entries.insert(entry, at: 0)
        saveEntries()
    }

    func delete(_ entry: TranscriptEntry) {
        if let audioURL = audioFileURL(for: entry) {
            try? FileManager.default.removeItem(at: audioURL)
        }
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    func audioFileURL(for entry: TranscriptEntry) -> URL? {
        guard let fileName = entry.audioFileName else { return nil }
        let url = recordingsURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func newRecordingURL() -> URL {
        let fileName = "\(Date().timeIntervalSinceReferenceDate).m4a"
        return recordingsURL.appendingPathComponent(fileName)
    }

    // MARK: - Private

    private func createDirectoriesIfNeeded() {
        let fm = FileManager.default
        try? fm.createDirectory(at: storageURL, withIntermediateDirectories: true)
        try? fm.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
    }

    private func loadEntries() {
        let path = transcriptsFileURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            logger.warning("No file at \(path)")
            return
        }
        do {
            let data = try Data(contentsOf: transcriptsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([TranscriptEntry].self, from: data)
            logger.notice("Loaded \(self.entries.count) entries from disk")
        } catch {
            logger.error("Failed to load: \(error)")
        }
    }

    private func saveEntries() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entries)
            try data.write(to: transcriptsFileURL, options: .atomic)
        } catch {
            logger.error("Failed to save transcripts: \(error)")
        }
    }
}
