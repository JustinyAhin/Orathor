import Foundation

struct TranscriptEntry: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let durationSeconds: Double
    let wordCount: Int
    let targetAppName: String?
    let targetAppBundleID: String?
}
