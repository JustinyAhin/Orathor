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
    /// Whether on-device smart formatting (Foundation Models) altered this transcript.
    /// `nil` for entries recorded before the feature existed.
    let smartFormatted: Bool?
    /// The original engine transcript before smart formatting or personal-dictionary
    /// corrections. `nil` when post-processing made no change or the entry predates it.
    let rawText: String?
    /// Label for the model that performed formatting (e.g. on-device Foundation Models).
    let formattingModel: String?

    init(
        text: String,
        timestamp: Date,
        durationSeconds: Double,
        wordCount: Int,
        targetAppName: String?,
        targetAppBundleID: String?,
        audioFileName: String? = nil,
        engine: SpeechEngine? = nil,
        smartFormatted: Bool? = nil,
        rawText: String? = nil,
        formattingModel: String? = nil
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
        self.smartFormatted = smartFormatted
        self.rawText = rawText
        self.formattingModel = formattingModel
    }
}
