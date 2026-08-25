import Foundation

enum TranscriptStatus: String, Codable, Equatable {
    case complete
    case partial
    case failed
}

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let durationSeconds: Double
    let wordCount: Int
    let targetAppName: String?
    let targetAppBundleID: String?
    let audioFileName: String?
    /// Engine that produced the stored text. `nil` when transcription failed.
    let engine: SpeechEngine?
    /// Engine selected by the user. Differs from `engine` after local fallback.
    let requestedEngine: SpeechEngine?
    /// `nil` for entries written before fallback status was introduced.
    let status: TranscriptStatus?
    let failureMessage: String?
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
        requestedEngine: SpeechEngine? = nil,
        status: TranscriptStatus? = .complete,
        failureMessage: String? = nil,
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
        self.requestedEngine = requestedEngine
        self.status = status
        self.failureMessage = failureMessage
        self.smartFormatted = smartFormatted
        self.rawText = rawText
        self.formattingModel = formattingModel
    }
}
