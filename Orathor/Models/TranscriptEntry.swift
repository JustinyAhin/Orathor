import Foundation

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let durationSeconds: Double
    let wordCount: Int
    let targetAppName: String?
    let targetAppBundleID: String?
    let audioFileName: String?
    let engine: SpeechEngine?

    init(
        text: String,
        timestamp: Date,
        durationSeconds: Double,
        wordCount: Int,
        targetAppName: String?,
        targetAppBundleID: String?,
        audioFileName: String? = nil,
        engine: SpeechEngine? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
        self.wordCount = wordCount
        self.targetAppName = targetAppName
        self.targetAppBundleID = targetAppBundleID
        self.audioFileName = audioFileName
        self.engine = engine
    }
}
