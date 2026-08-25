import AVFoundation

enum TranscriptionFailureKind: Equatable, Sendable {
    case transient
    case nonRecoverable
}

struct TranscriptionFailure: LocalizedError, Equatable, Sendable {
    let kind: TranscriptionFailureKind
    let message: String

    var errorDescription: String? { message }
}

enum TranscriptionStopResult: Equatable, Sendable {
    case completed
    case failed(TranscriptionFailure)
}

enum TranscriptionFallbackPolicy {
    static func shouldFallback(
        requestedEngine: SpeechEngine,
        failure: TranscriptionFailure?
    ) -> Bool {
        requestedEngine != .apple && failure?.kind == .transient
    }

    static func failureKind(forHTTPStatus statusCode: Int?) -> TranscriptionFailureKind {
        guard let statusCode else { return .transient }
        return (400..<500).contains(statusCode) ? .nonRecoverable : .transient
    }
}

protocol TranscriptionService: AnyObject {
    var transcribedText: String { get }
    var isTranscribing: Bool { get }

    func startTranscribing() async throws
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer)
    func processAudioData(_ data: Data)
    func stopTranscribing() async -> TranscriptionStopResult
    /// Releases persistent resources (e.g. a warm connection held between
    /// dictations) before the service is replaced.
    func shutdown()
}

extension TranscriptionService {
    func shutdown() {}
}
