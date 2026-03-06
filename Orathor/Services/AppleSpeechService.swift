import Speech

@Observable
final class AppleSpeechService: TranscriptionService {
    var transcribedText = ""
    var isTranscribing = false

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var finalContinuation: CheckedContinuation<Void, Never>?

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscribing(audioFormat: AVAudioFormat) async throws {
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        transcribedText = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
                if result.isFinal {
                    Task { @MainActor in
                        self.resolveFinal()
                    }
                }
            }
            if error != nil {
                Task { @MainActor in
                    self.resolveFinal()
                }
            }
        }

        recognitionRequest = request
        isTranscribing = true
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func processAudioData(_ data: Data) {
        // Not used by Apple Speech — buffers are passed directly
    }

    func stopTranscribing() async {
        recognitionRequest?.endAudio()

        // Wait for the final result or timeout after 2 seconds
        await withCheckedContinuation { continuation in
            finalContinuation = continuation

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.resolveFinal()
            }
        }

        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isTranscribing = false
    }

    private func resolveFinal() {
        finalContinuation?.resume()
        finalContinuation = nil
    }

    enum SpeechError: LocalizedError {
        case recognizerUnavailable

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Speech recognition is not available on this device."
            }
        }
    }
}
