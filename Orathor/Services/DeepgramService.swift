import AVFoundation

@Observable
final class DeepgramService: NSObject, TranscriptionService, URLSessionWebSocketDelegate {
    var transcribedText = ""
    var isTranscribing = false
    var onFailure: ((TranscriptionFailure) -> Void)?

    private let apiKey: String
    private let language: String
    private let context: TranscriptionContext
    private let targetSampleRate: Double = 16000
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var audioConverter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private var finalizeContinuation: CheckedContinuation<Bool, Never>?
    private var terminalFailure: TranscriptionFailure?

    // Sends into a socket whose handshake hasn't completed are silently dropped,
    // so messages queue under the lock until didOpen flushes them in order. The
    // lock also guards against the audio-thread/delegate-queue race.
    private let socketLock = NSLock()
    private var isSocketOpen = false
    private var pendingMessages: [URLSessionWebSocketTask.Message] = []
    private var connectStart: Date?
    private var didLogFirstTranscript = false

    // Warm connection: the socket is held open between dictations with
    // KeepAlive messages (Deepgram closes after ~10s of silence without them)
    // so the next dictation skips the handshake entirely.
    private var keepAliveTask: Task<Void, Never>?
    private let warmIdleLimit: TimeInterval = 120

    init(
        apiKey: String,
        language: String = "multi",
        context: TranscriptionContext = TranscriptionContext()
    ) {
        self.apiKey = apiKey
        self.language = language
        self.context = context
    }

    func startTranscribing() async throws {
        transcribedText = ""
        finalText = ""
        lastInterim = ""
        reconnectAttempts = 0
        terminalFailure = nil
        didLogFirstTranscript = false
        keepAliveTask?.cancel()
        keepAliveTask = nil

        if isSocketWarm() {
            connectStart = Date()
            isTranscribing = true
            DiagnosticLogger.shared.log("Deepgram: reusing warm connection")
            return
        }
        try await connect()
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        if audioConverter == nil || audioConverter?.inputFormat != buffer.format {
            setupAudioConverter(sourceFormat: buffer.format)
        }
        guard let data = convertBufferToData(buffer) else { return }
        processAudioData(data)
    }

    func processAudioData(_ data: Data) {
        guard data.count > 0 else { return }
        enqueueOrSend(.data(data))
    }

    func stopTranscribing() async -> TranscriptionStopResult {
        if let terminalFailure {
            return .failed(terminalFailure)
        }

        // Send Finalize to flush remaining audio, then wait for the response
        sendTextMessage(["type": "Finalize"])

        // Wait for final result or timeout after 1 second — the from_finalize
        // response normally arrives well under that; the timeout only covers a
        // dead connection.
        let didFinalize = await withCheckedContinuation { continuation in
            finalizeContinuation = continuation

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.resolveFinalize(succeeded: false)
            }
        }

        isTranscribing = false
        if didFinalize {
            // No CloseStream — hold the socket open for the next dictation
            startKeepAlive()
            return .completed
        }

        let failure = TranscriptionFailure(
            kind: .transient,
            message: "Deepgram did not finish the transcript before timing out."
        )
        terminalFailure = failure
        disconnect()
        return .failed(failure)
    }

    func shutdown() {
        isTranscribing = false
        disconnect()
    }

    private func resolveFinalize(succeeded: Bool) {
        finalizeContinuation?.resume(returning: succeeded)
        finalizeContinuation = nil
    }

    // MARK: - WebSocket Connection

    private func connect() async throws {
        let url = try Self.connectionURL(
            language: language,
            keywords: context.keywords,
            sampleRate: Int(targetSampleRate)
        )

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: request)

        markSocketClosed()
        connectStart = Date()

        urlSession = session
        webSocketTask = task
        task.resume()

        isTranscribing = true
        listenForMessages(on: task)
    }

    static func connectionURL(
        language: String,
        keywords: [String],
        sampleRate: Int = 16_000
    ) throws -> URL {
        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")
        var queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "sample_rate", value: String(sampleRate)),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "interim_results", value: "true"),
        ]
        queryItems.append(contentsOf: keywords.prefix(PersonalDictionarySnapshot.cloudHintLimit).map {
            URLQueryItem(name: "keyterm", value: $0)
        })
        components?.queryItems = queryItems
        guard let url = components?.url else { throw DeepgramError.invalidURL }
        return url
    }

    private func markSocketClosed() {
        socketLock.lock()
        isSocketOpen = false
        socketLock.unlock()
    }

    private func disconnect() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
        socketLock.lock()
        isSocketOpen = false
        pendingMessages = []
        socketLock.unlock()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    private func isSocketWarm() -> Bool {
        socketLock.lock()
        defer { socketLock.unlock() }
        return isSocketOpen && webSocketTask != nil
    }

    private func startKeepAlive() {
        keepAliveTask?.cancel()
        keepAliveTask = Task { @MainActor [weak self] in
            let idleStart = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                guard Date().timeIntervalSince(idleStart) < self.warmIdleLimit else {
                    DiagnosticLogger.shared.log("Deepgram: warm connection idle limit reached, closing")
                    self.disconnect()
                    return
                }
                self.sendTextMessage(["type": "KeepAlive"])
            }
        }
    }

    private func handleDisconnect(for task: URLSessionWebSocketTask) {
        guard markSocketClosedIfActive(task) else { return }
        guard isTranscribing else {
            // Warm connection died while idle — next start reconnects fresh
            disconnect()
            return
        }
        let statusCode = (task.response as? HTTPURLResponse)?.statusCode
        let failureKind = TranscriptionFallbackPolicy.failureKind(
            forHTTPStatus: statusCode)
        if failureKind == .nonRecoverable {
            let status = statusCode.map(String.init) ?? "unknown"
            let failure = TranscriptionFailure(
                kind: .nonRecoverable,
                message: "Deepgram rejected the connection (HTTP \(status))."
            )
            terminalFailure = failure
            isTranscribing = false
            disconnect()
            resolveFinalize(succeeded: false)
            onFailure?(failure)
            return
        }
        guard reconnectAttempts < maxReconnectAttempts else {
            let failure = TranscriptionFailure(
                kind: .transient,
                message: "Connection to Deepgram lost. Transcription may be incomplete."
            )
            terminalFailure = failure
            isTranscribing = false
            disconnect()
            resolveFinalize(succeeded: false)
            onFailure?(failure)
            return
        }
        releaseSocketForReconnect()
        reconnectAttempts += 1

        let delay = pow(2.0, Double(reconnectAttempts))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isTranscribing else { return }
            Task {
                try? await self.connect()
            }
        }
    }

    // MARK: - Message Handling

    private func listenForMessages(on task: URLSessionWebSocketTask) {
        task.receive { [weak self, weak task] result in
            guard let self, let task, self.isActive(task) else { return }

            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.handleMessage(text)
                }
                self.listenForMessages(on: task)
            case .failure:
                Task { @MainActor in
                    self.handleDisconnect(for: task)
                }
            }
        }
    }

    private func releaseSocketForReconnect() {
        socketLock.lock()
        let task = webSocketTask
        let session = urlSession
        webSocketTask = nil
        urlSession = nil
        isSocketOpen = false
        socketLock.unlock()

        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        do {
            let response = try JSONDecoder.deepgram.decode(DeepgramResponse.self, from: data)

            guard response.type == "Results",
                  let transcript = response.channel?.alternatives.first?.transcript else {
                return
            }

            let fromFinalize = response.fromFinalize ?? false

            Task { @MainActor in
                if !self.didLogFirstTranscript, !transcript.isEmpty {
                    self.didLogFirstTranscript = true
                    if let start = self.connectStart {
                        DiagnosticLogger.shared.log("Deepgram: first transcript \(Int(Date().timeIntervalSince(start) * 1000))ms after connect")
                    }
                }
                if response.isFinal == true {
                    self.appendFinalTranscript(transcript)
                    if fromFinalize {
                        self.resolveFinalize(succeeded: true)
                    }
                } else {
                    self.updateInterimTranscript(transcript)
                }
            }
        } catch {
            // Ignore non-Results messages (Metadata, etc.)
        }
    }

    private var finalText = ""
    private var lastInterim = ""

    private func appendFinalTranscript(_ transcript: String) {
        guard !transcript.isEmpty else { return }
        if finalText.isEmpty {
            finalText = transcript
        } else {
            finalText += " " + transcript
        }
        lastInterim = ""
        transcribedText = finalText
    }

    private func updateInterimTranscript(_ transcript: String) {
        lastInterim = transcript
        if finalText.isEmpty {
            transcribedText = transcript
        } else {
            transcribedText = finalText + " " + transcript
        }
    }

    // MARK: - Audio Conversion

    private func setupAudioConverter(sourceFormat: AVAudioFormat) {
        let sampleRate: Double = 16000
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ) else { return }

        targetFormat = target
        audioConverter = AVAudioConverter(from: sourceFormat, to: target)
    }

    private func convertBufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let converter = audioConverter, let targetFormat else { return nil }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outputFrameCount > 0 else { return nil }

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            return nil
        }

        var error: NSError?
        var hasData = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasData = true
            outStatus.pointee = .haveData
            return buffer
        }

        if error != nil { return nil }

        guard let int16Data = outputBuffer.int16ChannelData else { return nil }
        return Data(bytes: int16Data[0], count: Int(outputBuffer.frameLength) * 2)
    }

    // MARK: - Helpers

    private func sendTextMessage(_ dict: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        enqueueOrSend(.string(text))
    }

    private func enqueueOrSend(_ message: URLSessionWebSocketTask.Message) {
        socketLock.lock()
        defer { socketLock.unlock() }
        if isSocketOpen {
            send(message)
        } else {
            pendingMessages.append(message)
        }
    }

    private func send(_ message: URLSessionWebSocketTask.Message) {
        guard let task = webSocketTask else { return }
        task.send(message) { [weak self, weak task] error in
            guard error != nil, let self, let task else { return }
            Task { @MainActor in
                self.handleDisconnect(for: task)
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        socketLock.lock()
        guard webSocketTask === self.webSocketTask else {
            socketLock.unlock()
            return
        }
        isSocketOpen = true
        let queued = pendingMessages
        pendingMessages = []
        queued.forEach(send)
        socketLock.unlock()

        if let start = connectStart {
            DiagnosticLogger.shared.log("Deepgram: socket open \(Int(Date().timeIntervalSince(start) * 1000))ms after connect, flushed \(queued.count) queued messages")
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            self.handleDisconnect(for: webSocketTask)
        }
    }

    private func isActive(_ task: URLSessionWebSocketTask) -> Bool {
        socketLock.lock()
        defer { socketLock.unlock() }
        return task === webSocketTask
    }

    private func markSocketClosedIfActive(_ task: URLSessionWebSocketTask) -> Bool {
        socketLock.lock()
        defer { socketLock.unlock() }
        guard task === webSocketTask else { return false }
        isSocketOpen = false
        return true
    }

    // MARK: - Types

    enum DeepgramError: LocalizedError {
        case invalidURL
        case noApiKey
        case connectionFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Failed to create Deepgram connection URL."
            case .noApiKey: "Deepgram API key is required."
            case .connectionFailed(let reason): "Deepgram connection failed: \(reason)"
            }
        }
    }
}

// MARK: - Response Models

private struct DeepgramResponse: Decodable {
    let type: String
    let isFinal: Bool?
    let speechFinal: Bool?
    let fromFinalize: Bool?
    let channel: Channel?

    struct Channel: Decodable {
        let alternatives: [Alternative]
    }

    struct Alternative: Decodable {
        let transcript: String
        let confidence: Double?
    }
}

extension JSONDecoder {
    static let deepgram: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
