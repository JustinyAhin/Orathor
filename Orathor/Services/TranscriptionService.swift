import AVFoundation

protocol TranscriptionService {
    var transcribedText: String { get }
    var isTranscribing: Bool { get }

    func startTranscribing() async throws
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer)
    func processAudioData(_ data: Data)
    func stopTranscribing() async
    /// Releases persistent resources (e.g. a warm connection held between
    /// dictations) before the service is replaced.
    func shutdown()
}

extension TranscriptionService {
    func shutdown() {}
}
