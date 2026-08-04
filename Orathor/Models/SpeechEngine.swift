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
        case .openAIWhisper: "OpenAI Live Transcribe (Cloud)"
        }
    }

    var shortName: String {
        switch self {
        case .apple: "Apple Speech"
        case .deepgram: "Deepgram Nova"
        case .openAIWhisper: "OpenAI Live Transcribe"
        }
    }

    var compactName: String {
        switch self {
        case .apple: "Apple"
        case .deepgram: "Deepgram"
        case .openAIWhisper: "OpenAI"
        }
    }

    var description: String {
        switch self {
        case .apple: "On-device, no API key needed. Good for basic dictation."
        case .deepgram: "Cloud-based, higher accuracy. Requires API key."
        case .openAIWhisper: "Cloud-based live transcription. Requires API key."
        }
    }
}
