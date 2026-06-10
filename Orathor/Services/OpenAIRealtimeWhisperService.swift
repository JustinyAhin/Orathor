import AVFoundation
import Foundation

@Observable
final class OpenAIRealtimeWhisperService: NSObject, TranscriptionService, URLSessionWebSocketDelegate {
    var transcribedText = ""
    var isTranscribing = false
    var onError: ((String) -> Void)?

    private let apiKey: String
    private let language: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var audioConverter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var stopContinuation: CheckedContinuation<Void, Never>?
    private var stopTimeoutWorkItem: DispatchWorkItem?
    private var finalTextByItemID: [String: String] = [:]
    private var itemOrder: [String] = []
    private var activeDeltaItemID: String?
    private var activeDeltaText = ""

    // Sends into a socket whose handshake hasn't completed are silently dropped,
    // so messages queue under the lock until didOpen flushes them in order (after
    // session.update). The lock also guards the audio-thread/delegate-queue race.
    private let socketLock = NSLock()
    private var isSocketOpen = false
    private var pendingMessages: [URLSessionWebSocketTask.Message] = []
    private var connectStart: Date?
    private var didLogFirstTranscript = false

    init(apiKey: String, language: String = "multi") {
        self.apiKey = apiKey
        self.language = language
    }

    func startTranscribing() async throws {
        guard !apiKey.isEmpty else {
            throw OpenAIRealtimeWhisperError.noApiKey
        }

        transcribedText = ""
        finalTextByItemID = [:]
        itemOrder = []
        activeDeltaItemID = nil
        activeDeltaText = ""
        didLogFirstTranscript = false

        try await connect()
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        if audioConverter == nil {
            setupAudioConverter(sourceFormat: buffer.format)
        }
        guard let data = convertBufferToData(buffer) else { return }
        processAudioData(data)
    }

    func processAudioData(_ data: Data) {
        guard data.count > 0 else { return }

        sendJSON([
            "type": "input_audio_buffer.append",
            "audio": data.base64EncodedString()
        ])
    }

    func stopTranscribing() async {
        guard isTranscribing else { return }

        sendJSON(["type": "input_audio_buffer.commit"])

        await withCheckedContinuation { continuation in
            stopContinuation = continuation

            // Generous backstop: the completed event is the normal exit and a dead
            // connection resolves via handleDisconnect — expiring early drops the
            // tail of speech the server is still transcribing
            let timeout = DispatchWorkItem { [weak self] in
                DiagnosticLogger.shared.log("Stop timed out waiting for final transcript — tail may be cut")
                self?.resolveStop()
            }
            stopTimeoutWorkItem = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: timeout)
        }

        isTranscribing = false
        disconnect()
    }

    private func resolveStop() {
        stopTimeoutWorkItem?.cancel()
        stopTimeoutWorkItem = nil
        stopContinuation?.resume()
        stopContinuation = nil
    }

    // MARK: - WebSocket Connection

    private func connect() async throws {
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription") else {
            throw OpenAIRealtimeWhisperError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    private func handleDisconnect() {
        guard isTranscribing else { return }
        isTranscribing = false
        resolveStop()
        onError?("Connection to OpenAI lost. Transcription may be incomplete.")
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
        guard let data = text.data(using: .utf8),
              let event = try? JSONDecoder().decode(OpenAIRealtimeEvent.self, from: data) else {
            return
        }

        Task { @MainActor in
            switch event.type {
            case "conversation.item.input_audio_transcription.delta":
                self.applyDelta(event)
            case "conversation.item.input_audio_transcription.completed":
                self.applyCompleted(event)
            case "error":
                self.handleErrorEvent(event)
            default:
                break
            }
        }
    }

    private func applyDelta(_ event: OpenAIRealtimeEvent) {
        guard let delta = event.delta, !delta.isEmpty else { return }
        if !didLogFirstTranscript {
            didLogFirstTranscript = true
            if let start = connectStart {
                DiagnosticLogger.shared.log("OpenAI: first transcript \(Int(Date().timeIntervalSince(start) * 1000))ms after connect")
            }
        }
        let itemID = event.itemID ?? activeDeltaItemID ?? "active"

        if activeDeltaItemID != itemID {
            activeDeltaItemID = itemID
            activeDeltaText = ""
        }
        if !itemOrder.contains(itemID) {
            itemOrder.append(itemID)
        }

        activeDeltaText += delta
        rebuildTranscribedText()
    }

    private func applyCompleted(_ event: OpenAIRealtimeEvent) {
        guard let transcript = event.transcript else {
            resolveStop()
            return
        }

        let itemID = event.itemID ?? activeDeltaItemID ?? UUID().uuidString
        if !itemOrder.contains(itemID) {
            itemOrder.append(itemID)
        }
        finalTextByItemID[itemID] = transcript

        if activeDeltaItemID == itemID || event.itemID == nil {
            activeDeltaItemID = nil
            activeDeltaText = ""
        }

        rebuildTranscribedText()
        resolveStop()
    }

    private func handleErrorEvent(_ event: OpenAIRealtimeEvent) {
        // The flush-commit at stop fails harmlessly when no audio was ever
        // appended (e.g. instant tap) — finish the stop without surfacing it
        if event.error?.code == "input_audio_buffer_commit_empty" {
            resolveStop()
            return
        }
        let message = event.error?.message ?? "OpenAI transcription failed."
        onError?(message)
        resolveStop()
    }

    private func rebuildTranscribedText() {
        var segments = itemOrder.compactMap { finalTextByItemID[$0] }.filter { !$0.isEmpty }
        if !activeDeltaText.isEmpty {
            segments.append(activeDeltaText)
        }
        transcribedText = segments.joined(separator: " ")
    }

    // MARK: - Session Configuration

    private func sessionUpdatePayload() -> [String: Any] {
        var transcription: [String: Any] = [
            "model": "gpt-realtime-whisper",
            // Latency/accuracy tradeoff — "low" targets live captions
            "delay": "low"
        ]

        if language != "multi" {
            transcription["language"] = language
        }

        return [
            "type": "session.update",
            "session": [
                "type": "transcription",
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "transcription": transcription,
                        // gpt-realtime-whisper streams deltas natively and rejects
                        // turn detection — leave it off and commit manually at stop
                        "turn_detection": NSNull()
                    ]
                ]
            ]
        ]
    }

    // MARK: - Audio Conversion

    private func setupAudioConverter(sourceFormat: AVAudioFormat) {
        let sampleRate: Double = 24000
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

    private func sendJSON(_ dict: [String: Any]) {
        guard let message = jsonMessage(dict) else { return }
        enqueueOrSend(message)
    }

    private func jsonMessage(_ dict: [String: Any]) -> URLSessionWebSocketTask.Message? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return .string(text)
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
            guard error != nil else { return }
            Task { @MainActor in
                self.handleDisconnect()
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        socketLock.lock()
        isSocketOpen = true
        if let update = jsonMessage(sessionUpdatePayload()) {
            send(update)
        }
        let queued = pendingMessages
        pendingMessages = []
        queued.forEach(send)
        socketLock.unlock()

        if let start = connectStart {
            DiagnosticLogger.shared.log("OpenAI: socket open \(Int(Date().timeIntervalSince(start) * 1000))ms after connect, flushed \(queued.count) queued messages")
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            self.handleDisconnect()
        }
    }

    // MARK: - Types

    enum OpenAIRealtimeWhisperError: LocalizedError {
        case invalidURL
        case noApiKey

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Failed to create OpenAI connection URL."
            case .noApiKey: "OpenAI API key is required."
            }
        }
    }
}

private struct OpenAIRealtimeEvent: Decodable {
    let type: String
    let itemID: String?
    let delta: String?
    let transcript: String?
    let error: OpenAIRealtimeError?

    enum CodingKeys: String, CodingKey {
        case type
        case itemID = "item_id"
        case delta
        case transcript
        case error
    }
}

private struct OpenAIRealtimeError: Decodable {
    let message: String?
    let code: String?
}
