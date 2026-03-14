import AVFoundation

@Observable
final class DeepgramService: NSObject, TranscriptionService, URLSessionWebSocketDelegate {
    var transcribedText = ""
    var isTranscribing = false
    var onError: ((String) -> Void)?

    private let apiKey: String
    private let language: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var audioConverter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private var lastAudioFormat: AVAudioFormat?
    private var finalizeContinuation: CheckedContinuation<Void, Never>?

    init(apiKey: String, language: String = "multi") {
        self.apiKey = apiKey
        self.language = language
    }

    func startTranscribing(audioFormat: AVAudioFormat) async throws {
        transcribedText = ""
        lastAudioFormat = audioFormat
        reconnectAttempts = 0

        setupAudioConverter(sourceFormat: audioFormat)
        try await connect()
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let data = convertBufferToData(buffer) else { return }
        processAudioData(data)
    }

    func processAudioData(_ data: Data) {
        guard data.count > 0 else { return }
        webSocketTask?.send(.data(data)) { error in
            if error != nil {
                Task { @MainActor in
                    self.handleDisconnect()
                }
            }
        }
    }

    func stopTranscribing() async {
        // Send Finalize to flush remaining audio, then wait for the response
        sendTextMessage(["type": "Finalize"])

        // Wait for final result or timeout after 2 seconds
        await withCheckedContinuation { continuation in
            finalizeContinuation = continuation

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.resolveFinalize()
            }
        }

        sendTextMessage(["type": "CloseStream"])
        isTranscribing = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.disconnect()
        }
    }

    private func resolveFinalize() {
        finalizeContinuation?.resume()
        finalizeContinuation = nil
    }

    // MARK: - WebSocket Connection

    private func connect() async throws {
        var params = [
            "model=nova-3",
            "language=\(language)",
            "encoding=linear16",
            "channels=1",
            "punctuate=true",
            "smart_format=true",
            "interim_results=true"
        ]

        if let format = targetFormat {
            params.append("sample_rate=\(Int(format.sampleRate))")
        }

        let queryString = params.joined(separator: "&")
        guard let url = URL(string: "wss://api.deepgram.com/v1/listen?\(queryString)") else {
            throw DeepgramError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: request)

        urlSession = session
        webSocketTask = task
        task.resume()

        isTranscribing = true
        listenForMessages()
    }

    private func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    private func handleDisconnect() {
        guard isTranscribing else { return }
        guard reconnectAttempts < maxReconnectAttempts else {
            onError?("Connection to Deepgram lost. Transcription may be incomplete.")
            return
        }
        reconnectAttempts += 1

        let delay = pow(2.0, Double(reconnectAttempts))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isTranscribing, let format = self.lastAudioFormat else { return }
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
        webSocketTask?.send(.string(text)) { _ in }
    }

    // MARK: - URLSessionWebSocketDelegate

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
