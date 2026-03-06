import AVFoundation

protocol TranscriptionService {
    var transcribedText: String { get }
    var isTranscribing: Bool { get }

    func startTranscribing(audioFormat: AVAudioFormat) async throws
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer)
    func processAudioData(_ data: Data)
    func stopTranscribing() async
}
