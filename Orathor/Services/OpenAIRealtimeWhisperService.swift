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

    init(apiKey: String, language: String = "multi") {
        self.apiKey = apiKey
        self.language = language
    }

    func startTranscribing(audioFormat: AVAudioFormat) async throws {
        guard !apiKey.isEmpty else {
            throw OpenAIRealtimeWhisperError.noApiKey
        }

        transcribedText = ""
        finalTextByItemID = [:]
        itemOrder = []
        activeDeltaItemID = nil
        activeDeltaText = ""

        setupAudioConverter(sourceFormat: audioFormat)
        try await connect()
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
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

            let timeout = DispatchWorkItem { [weak self] in
                self?.resolveStop()
            }
            stopTimeoutWorkItem = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeout)
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

        urlSession = session
        webSocketTask = task
        task.resume()

        isTranscribing = true
        listenForMessages()
        sendSessionUpdate()
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

    private func sendSessionUpdate() {
        var transcription: [String: Any] = [
            "model": "gpt-realtime-whisper"
        ]

        if language != "multi" {
            transcription["language"] = language
        }

        sendJSON([
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
                        "turn_detection": NSNull()
                    ]
                ]
            ]
        ])
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
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(text)) { error in
            guard error != nil else { return }
            Task { @MainActor in
                self.handleDisconnect()
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

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
}
