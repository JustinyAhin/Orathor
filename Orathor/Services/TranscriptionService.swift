import AVFoundation

protocol TranscriptionService {
    var transcribedText: String { get }
    var isTranscribing: Bool { get }

    func startTranscribing(audioFormat: AVAudioFormat) throws
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer)
    func stopTranscribing()
}
