import Foundation

enum SpeechEngine: String, CaseIterable, Identifiable, Codable {
    case apple = "apple"
    case deepgram = "deepgram"
    case openAIWhisper = "openAIWhisper"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: "Apple (Local)"
        case .deepgram: "Deepgram Nova (Cloud)"
        case .openAIWhisper: "OpenAI Whisper (Cloud)"
        }
    }

    var description: String {
        switch self {
        case .apple: "On-device, no API key needed. Good for basic dictation."
        case .deepgram: "Cloud-based, higher accuracy. Requires API key."
        case .openAIWhisper: "Cloud-based, realtime GPT Whisper transcription. Requires API key."
        }
    }
}
