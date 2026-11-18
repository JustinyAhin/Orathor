import Foundation
import os

private let logger = Logger(subsystem: "segbedji.Orathor", category: "TranscriptHistory")

@Observable
final class TranscriptHistoryService {
    private(set) var entries: [TranscriptEntry] = []
    private(set) var loadErrorMessage: String?

    private let storageURL: URL
    private let recordingsURL: URL
    private let transcriptsFileURL: URL
    private let shouldPersist: Bool

    init(storageURL: URL? = nil) {
        let manager = FileManager.default
        let appSupport =
            manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        self.storageURL =
            storageURL ?? appSupport.appendingPathComponent("segbedji.Orathor", isDirectory: true)
        recordingsURL = self.storageURL.appendingPathComponent("Recordings", isDirectory: true)
        transcriptsFileURL = self.storageURL.appendingPathComponent("transcripts.json")
        shouldPersist = storageURL != nil || !AppRuntime.isRunningTests

        guard shouldPersist else { return }
        createDirectoriesIfNeeded()
        loadEntries()
    }

    var recordingsDirectory: URL { recordingsURL }

    var todayEntries: [TranscriptEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDateInToday($0.timestamp) }
    }

    var todayWordCount: Int {
        todayEntries.reduce(0) { $0 + $1.wordCount }
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let activeDays = Set(entries.map { calendar.startOfDay(for: $0.timestamp) })
        let today = calendar.startOfDay(for: Date())

        var day = today
        if !activeDays.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while activeDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    func add(_ entry: TranscriptEntry) {
        guard loadErrorMessage == nil else {
            logger.error("Refusing to change history after a loading error")
            return
        }
        entries.insert(entry, at: 0)
        saveEntries()
    }

    func delete(_ entry: TranscriptEntry) {
        guard loadErrorMessage == nil else {
            logger.error("Refusing to delete history after a loading error")
            return
        }
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
            loadErrorMessage =
                "Couldn’t load your saved transcripts. Recording is paused to protect your history."
            logger.error("Failed to load: \(error)")
        }
    }

    private func saveEntries() {
        guard shouldPersist, loadErrorMessage == nil else { return }
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
