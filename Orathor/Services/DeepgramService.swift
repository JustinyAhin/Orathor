import AVFoundation

@Observable
final class DeepgramService: NSObject, TranscriptionService, URLSessionWebSocketDelegate {
    var transcribedText = ""
    var isTranscribing = false
    var onError: ((String) -> Void)?

    private let apiKey: String
    private let language: String
    private let targetSampleRate: Double = 16000
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var audioConverter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private var finalizeContinuation: CheckedContinuation<Void, Never>?

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

    init(apiKey: String, language: String = "multi") {
        self.apiKey = apiKey
        self.language = language
    }

    func startTranscribing() async throws {
        transcribedText = ""
        finalText = ""
        lastInterim = ""
        reconnectAttempts = 0
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

    func stopTranscribing() async {
        // Send Finalize to flush remaining audio, then wait for the response
        sendTextMessage(["type": "Finalize"])

        // Wait for final result or timeout after 1 second — the from_finalize
        // response normally arrives well under that; the timeout only covers a
        // dead connection.
        await withCheckedContinuation { continuation in
            finalizeContinuation = continuation

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.resolveFinalize()
            }
        }

        isTranscribing = false
        // No CloseStream — hold the socket open for the next dictation
        startKeepAlive()
    }

    func shutdown() {
        isTranscribing = false
        disconnect()
    }

    private func resolveFinalize() {
        finalizeContinuation?.resume()
        finalizeContinuation = nil
    }

    // MARK: - WebSocket Connection

    private func connect() async throws {
        let params = [
            "model=nova-3",
            "language=\(language)",
            "encoding=linear16",
            "channels=1",
            "sample_rate=\(Int(targetSampleRate))",
            "punctuate=true",
            "smart_format=true",
            "interim_results=true"
        ]

        let queryString = params.joined(separator: "&")
        guard let url = URL(string: "wss://api.deepgram.com/v1/listen?\(queryString)") else {
            throw DeepgramError.invalidURL
        }

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
        listenForMessages()
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

    private func handleDisconnect() {
        markSocketClosed()
        guard isTranscribing else {
            // Warm connection died while idle — next start reconnects fresh
            disconnect()
            return
        }
        guard reconnectAttempts < maxReconnectAttempts else {
            onError?("Connection to Deepgram lost. Transcription may be incomplete.")
            return
        }
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

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.handleMessage(text)
                }
                self.listenForMessages()
            case .failure:
                Task { @MainActor in
                    self.handleDisconnect()
                }
            }
        }
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
                        self.resolveFinalize()
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
        webSocketTask?.send(message) { error in
            if error != nil {
                Task { @MainActor in
                    self.handleDisconnect()
                }
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        socketLock.lock()
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
            self.handleDisconnect()
        }
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
