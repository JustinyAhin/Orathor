import Foundation

enum SpeechEngine: String, CaseIterable, Identifiable, Codable {
    case apple = "apple"
    case deepgram = "deepgram"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: "Apple (Local)"
        case .deepgram: "Deepgram Nova (Cloud)"
        }
    }

    var description: String {
        switch self {
        case .apple: "On-device, no API key needed. Good for basic dictation."
        case .deepgram: "Cloud-based, higher accuracy. Requires API key."
        }
    }
}
