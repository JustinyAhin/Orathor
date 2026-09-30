@preconcurrency import AVFoundation
import os

/// Capture, resampling, and the FIFO are locked together. The microphone thread
/// never waits for inference or a pipe write. A 30-second backlog is a failure,
/// rather than silent audio loss or an unbounded allocation.
nonisolated final class PhononAudioQueue: Sendable {
    enum CaptureResult: Sendable { case accepted, inactive, overflow, invalidFormat }
    private struct State {
        var session: UUID?
        var bytes = Data()
        var converter: AVAudioConverter?
        var targetFormat: AVAudioFormat?
    }
    private let lock = OSAllocatedUnfairLock(initialState: State())
    private static let maximumBytes = 16_000 * 4 * 30
    static let frameBytes = 800 * 4

    func begin(session: UUID) { lock.withLock { $0 = State(session: session) } }
    func end() { lock.withLock { $0.session = nil } }
    func clear() { lock.withLock { $0 = State() } }
    var session: UUID? { lock.withLock { $0.session } }

    func append(_ data: Data) -> CaptureResult {
        lock.withLock { state in
            guard state.session != nil else { return .inactive }
            return Self.append(data, to: &state)
        }
    }

    func capture(_ buffer: AVAudioPCMBuffer) -> CaptureResult {
        lock.withLock { state in
            guard state.session != nil else { return .inactive }
            guard buffer.format.sampleRate > 0, buffer.frameLength > 0 else { return .invalidFormat }
            if state.converter?.inputFormat != buffer.format {
                guard
                    let target = AVAudioFormat(
                        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
                    let converter = AVAudioConverter(from: buffer.format, to: target)
                else { return .invalidFormat }
                state.targetFormat = target
                state.converter = converter
            }
            guard let converter = state.converter, let target = state.targetFormat,
                let converted = AVAudioPCMBuffer(
                    pcmFormat: target,
                    frameCapacity: AVAudioFrameCount(
                        ceil(Double(buffer.frameLength) * 16_000 / buffer.format.sampleRate)) + 16)
            else { return .invalidFormat }
            var provided = false
            var error: NSError?
            let status = converter.convert(to: converted, error: &error) { _, status in
                if provided {
                    status.pointee = .noDataNow
                    return nil
                }
                provided = true
                status.pointee = .haveData
                return buffer
            }
            guard error == nil, status != .error, let samples = converted.floatChannelData?[0] else {
                return .invalidFormat
            }
            let data = Data(bytes: samples, count: Int(converted.frameLength) * MemoryLayout<Float>.size)
            return Self.append(data, to: &state)
        }
    }

    private static func append(_ data: Data, to state: inout State) -> CaptureResult {
        guard data.count % 4 == 0 else { return .invalidFormat }
        guard state.bytes.count + data.count <= maximumBytes else { return .overflow }
        state.bytes.append(data)
        return .accepted
    }

    /// Ended queues can still be drained at key-up; their bytes keep FIFO order.
    func takeFrame(flush: Bool) -> Data? {
        lock.withLock { state in
            guard !state.bytes.isEmpty, flush || state.bytes.count >= Self.frameBytes else { return nil }
            let count = min(state.bytes.count, Self.frameBytes)
            let data = state.bytes.prefix(count)
            state.bytes.removeFirst(count)
            return Data(data)
        }
    }
}

@MainActor
@Observable
final class PhononSpeechService: TranscriptionService {
    private(set) var transcribedText = ""
    private(set) var isTranscribing = false
    var onFailure: ((TranscriptionFailure) -> Void)?
    var onPreparingChanged: ((Bool) -> Void)?

    @ObservationIgnored private let worker: any PhononWorkerControlling
    @ObservationIgnored private let configurationProvider: @MainActor () throws -> PhononConfiguration
    nonisolated private let audioQueue = PhononAudioQueue()
    private var sessionID: UUID?
    private var terminalFailure: TranscriptionFailure?
    private var isStopping = false
    @ObservationIgnored private var pumpTask: Task<Void, Never>?
    @ObservationIgnored private var idleTask: Task<Void, Never>?

    init(
        worker: (any PhononWorkerControlling)? = nil,
        configurationProvider: (@MainActor () throws -> PhononConfiguration)? = nil
    ) {
        let activeWorker = worker ?? PhononWorker()
        self.worker = activeWorker
        self.configurationProvider = configurationProvider ?? { try PhononRuntime.shared.configuration() }
        activeWorker.onPartial = { [weak self] session, text in
            guard let self, self.sessionID == session, self.terminalFailure == nil else { return }
            self.transcribedText = text
        }
        activeWorker.onFailure = { [weak self] failure in self?.fail(failure) }
    }

    func prepare() async throws {
        onPreparingChanged?(true)
        defer { onPreparingChanged?(false) }
        try await worker.prepare(configuration: configurationProvider())
        if !isTranscribing { scheduleIdleRelease() }
    }

    func startTranscribing() async throws {
        guard !isTranscribing else {
            throw TranscriptionFailure(
                kind: .nonRecoverable, message: "A Phonon recording is already active.")
        }
        idleTask?.cancel()
        idleTask = nil
        terminalFailure = nil
        transcribedText = ""
        isStopping = false
        let session = UUID()
        sessionID = session
        isTranscribing = true
        audioQueue.begin(session: session)
        do {
            try await prepare()
            guard sessionID == session else { throw CancellationError() }
            try await worker.start(session: session)
            guard sessionID == session else { throw CancellationError() }
            pumpTask = Task { [weak self] in await self?.pump(session: session) }
        } catch {
            guard sessionID == session else { throw error }
            isTranscribing = false
            audioQueue.clear()
            sessionID = nil
            terminalFailure = Self.failure(error)
            worker.shutdown()
            throw error
        }
    }

    nonisolated func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let session = audioQueue.session
        checkCapture(audioQueue.capture(buffer), session: session)
    }

    /// Raw audio follows this engine's 16 kHz mono Float32 little-endian contract.
    nonisolated func processAudioData(_ data: Data) {
        let session = audioQueue.session
        checkCapture(audioQueue.append(data), session: session)
    }

    nonisolated private func checkCapture(_ result: PhononAudioQueue.CaptureResult, session: UUID?) {
        guard result == .overflow || result == .invalidFormat else { return }
        Task { @MainActor [weak self] in
            guard let self, let session, self.sessionID == session else { return }
            self.fail(
                TranscriptionFailure(
                    kind: .transient,
                    message: result == .overflow
                        ? "Phonon could not keep up with the recording."
                        : "Phonon could not convert the microphone audio."))
        }
    }

    private func pump(session: UUID) async {
        while sessionID == session, terminalFailure == nil, !Task.isCancelled {
            if let data = audioQueue.takeFrame(flush: isStopping) {
                do { try await worker.feed(data, session: session) } catch {
                    guard sessionID == session else { return }
                    fail(Self.failure(error))
                    return
                }
            } else if isStopping {
                return
            } else {
                do { try await Task.sleep(for: .milliseconds(10)) } catch { return }
            }
        }
    }

    func stopTranscribing() async -> TranscriptionStopResult {
        audioQueue.end()
        guard let session = sessionID else {
            return terminalFailure.map { .failed($0) } ?? .completed
        }
        isStopping = true
        await pumpTask?.value
        pumpTask = nil
        if terminalFailure == nil {
            do {
                let text = try await worker.finish(session: session)
                guard sessionID == session else {
                    return .failed(
                        TranscriptionFailure(kind: .transient, message: "Phonon recording was interrupted."))
                }
                transcribedText = text
            } catch { fail(Self.failure(error)) }
        }
        isTranscribing = false
        sessionID = nil
        audioQueue.clear()
        if let terminalFailure { return .failed(terminalFailure) }
        // Keep the loaded engine warm for consecutive dictations, then release
        // its approximately 3 GB memory footprint after two minutes idle.
        scheduleIdleRelease()
        return .completed
    }

    private func scheduleIdleRelease() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(120)) } catch { return }
            guard !Task.isCancelled, let self, !self.isTranscribing else { return }
            self.worker.shutdown()
            self.idleTask = nil
            DiagnosticLogger.shared.log("Phonon: released idle model")
        }
    }

    func shutdown() {
        sessionID = nil
        isTranscribing = false
        isStopping = false
        onPreparingChanged?(false)
        pumpTask?.cancel()
        pumpTask = nil
        idleTask?.cancel()
        idleTask = nil
        audioQueue.clear()
        worker.shutdown()
    }

    private func fail(_ failure: TranscriptionFailure) {
        guard terminalFailure == nil else { return }
        terminalFailure = failure
        audioQueue.end()
        worker.shutdown()
        if sessionID != nil { onFailure?(failure) }
    }

    private static func failure(_ error: Error) -> TranscriptionFailure {
        (error as? TranscriptionFailure)
            ?? TranscriptionFailure(kind: .transient, message: error.localizedDescription)
    }
}
