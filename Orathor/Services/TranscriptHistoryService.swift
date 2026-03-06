import Foundation

@Observable
final class TranscriptHistoryService {
    private(set) var entries: [TranscriptEntry] = []

    func add(_ entry: TranscriptEntry) {
        entries.insert(entry, at: 0)
    }
}
