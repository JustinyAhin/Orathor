import AVFoundation

@Observable
final class AudioService {
    var isRecording = false
    var audioLevel: Float = 0

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    var onAudioBuffer: ((AVAudioPCMBuffer, AVAudioFormat) -> Void)?

    func startRecording(saveTo fileURL: URL? = nil) throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        if let fileURL {
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            audioFile = try AVAudioFile(forWriting: fileURL, settings: outputSettings)
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let level = self.calculateLevel(buffer: buffer)
            Task { @MainActor in
                self.audioLevel = level
            }
            try? self.audioFile?.write(from: buffer)
            self.onAudioBuffer?(buffer, format)
        }

        engine.prepare()
        try engine.start()
        audioEngine = engine
        isRecording = true
    }

    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        isRecording = false
        audioLevel = 0
    }

    private func calculateLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        let samples = channelData[0]

        var sum: Float = 0
        for i in 0..<frames {
            sum += samples[i] * samples[i]
        }
        let rms = sqrt(sum / Float(frames))
        return min(rms * 5, 1.0)
    }
}
