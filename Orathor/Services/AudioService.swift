import AVFoundation
import os

nonisolated final class AudioMeterAccumulator: Sendable {
    private struct State {
        var lastSubmitted = AudioMeterLevel.silence
        var pending: AudioMeterLevel?
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())

    func submit(_ level: AudioMeterLevel) {
        lock.withLock { state in
            guard level != state.lastSubmitted else { return }
            state.lastSubmitted = level
            state.pending = level
        }
    }

    func takePending() -> AudioMeterLevel? {
        lock.withLock { state in
            defer { state.pending = nil }
            return state.pending
        }
    }

    func reset() {
        lock.withLock { state in
            state = State()
        }
    }
}

@Observable
final class AudioService {
    var isRecording = false
    var audioLevel = AudioMeterLevel.silence

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private let meterAccumulator = AudioMeterAccumulator()
    private var meterTask: Task<Void, Never>?
    private var meterStartDate: Date?
    private var meterPublicationCount = 0
    private let diag = DiagnosticLogger.shared
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
            let level = AudioMeterLevel(normalized: Self.calculateLevel(buffer: buffer))
            self.meterAccumulator.submit(level)
            try? self.audioFile?.write(from: buffer)
            self.onAudioBuffer?(buffer, format)
        }

        meterAccumulator.reset()
        audioLevel = .silence
        engine.prepare()
        try engine.start()
        audioEngine = engine
        isRecording = true
        meterStartDate = Date()
        meterPublicationCount = 0
        startMeterUpdates()
    }

    func stopRecording() {
        meterTask?.cancel()
        meterTask = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        isRecording = false
        meterAccumulator.reset()
        audioLevel = .silence
        logMeterSummary()
    }

    private func startMeterUpdates() {
        meterTask?.cancel()
        meterTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .nanoseconds(33_333_334))
                } catch {
                    return
                }
                guard let self,
                      let level = self.meterAccumulator.takePending(),
                      level != self.audioLevel else { continue }
                self.audioLevel = level
                self.meterPublicationCount += 1
            }
        }
    }

    private func logMeterSummary() {
        guard let meterStartDate else { return }
        let duration = Date().timeIntervalSince(meterStartDate)
        let rate = duration > 0 ? Double(meterPublicationCount) / duration : 0
        diag.log(
            "Audio meter — duration: \(String(format: "%.2f", duration))s, "
                + "published: \(meterPublicationCount), rate: \(String(format: "%.1f", rate))Hz"
        )
        self.meterStartDate = nil
        meterPublicationCount = 0
    }

    nonisolated private static func calculateLevel(buffer: AVAudioPCMBuffer) -> Float {
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
