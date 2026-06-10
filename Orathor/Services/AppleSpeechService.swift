import AVFoundation
import Speech

/// On-device transcription using the modern `SpeechAnalyzer` / `SpeechTranscriber`
/// stack (macOS 26+). Falls back to `DictationTranscriber` on unsupported devices.
@Observable
final class AppleSpeechService: TranscriptionService {
    var transcribedText = ""
    var isTranscribing = false

    /// Invoked while a language model is downloading on first use. The view model
    /// uses this to surface a "preparing language…" state in the overlay.
    var onPreparingChanged: ((Bool) -> Void)?

    private let locale: Locale
    private let diag = DiagnosticLogger.shared

    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Never>?

    /// Accumulated finalized text. Volatile (in-progress) results are appended
    /// transiently on top of this for display, then folded in once finalized.
    private var finalizedText = ""
    private var isStarting = false
    /// Set when a start fails for a non-transient reason (e.g. unsupported locale)
    /// so the per-buffer start attempts don't re-run the whole path every buffer.
    private var startFailed = false
    /// Rate-limits audio-conversion failure logging to once per session.
    private var didLogConversionFailure = false

    init(language: String = "multi") {
        // "multi" (auto) maps to the system locale; otherwise honour the setting.
        self.locale = language == "multi" ? .current : Locale(identifier: language)
    }

    /// Speech-framework authorization gate (independent of recognizer class).
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscribing(audioFormat: AVAudioFormat) async throws {
        // Guard against re-entrancy: the view model spawns a start task on every
        // audio buffer until `isTranscribing` flips true, and model download is async.
        guard !isTranscribing, !isStarting, !startFailed else { return }
        isStarting = true
        defer { isStarting = false }

        transcribedText = ""
        finalizedText = ""

        if SpeechTranscriber.isAvailable {
            // Resolve to a model-supported locale (region-tolerant). Fall back to
            // English if the system locale has no on-device model.
            var resolved = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
            if resolved == nil {
                resolved = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
            }
            guard let resolved else {
                startFailed = true
                diag.log("Apple: SpeechTranscriber — no model for locale \(locale.identifier) (or en-US fallback)")
                throw SpeechError.localeNotSupported(locale)
            }
            diag.log("Apple: SpeechTranscriber — requested \(locale.identifier) → resolved \(resolved.identifier(.bcp47))")

            let transcriber = SpeechTranscriber(locale: resolved, preset: .progressiveTranscription)
            try await prepare(module: transcriber)
            recognizerTask = consumeResults(transcriber.results) { $0.text }
            try await startAnalyzer(with: transcriber)
        } else {
            var resolved = await DictationTranscriber.supportedLocale(equivalentTo: locale)
            if resolved == nil {
                resolved = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
            }
            guard let resolved else {
                startFailed = true
                diag.log("Apple: DictationTranscriber fallback — no model for locale \(locale.identifier) (or en-US fallback)")
                throw SpeechError.localeNotSupported(locale)
            }
            diag.log("Apple: DictationTranscriber fallback (SpeechTranscriber unavailable) — requested \(locale.identifier) → resolved \(resolved.identifier(.bcp47))")

            let dictation = DictationTranscriber(locale: resolved, preset: .progressiveLongDictation)
            try await prepare(module: dictation)
            recognizerTask = consumeResults(dictation.results) { $0.text }
            try await startAnalyzer(with: dictation)
        }

        isTranscribing = true
    }

    private func startAnalyzer(with module: any SpeechModule) async throws {
        let analyzer = SpeechAnalyzer(modules: [module])
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])
        diag.log("Apple: analyzer format \(analyzerFormat.map { "\(Int($0.sampleRate))Hz, \($0.channelCount)ch" } ?? "nil")")

        let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
        try await analyzer.start(inputSequence: stream)

        self.analyzer = analyzer
        self.inputBuilder = builder
    }

    /// Consumes a transcriber's result stream, reconciling volatile vs final text.
    /// Generic over the concrete result type (`SpeechTranscriber.Result` /
    /// `DictationTranscriber.Result`), both of which expose `text` and `isFinal`.
    private func consumeResults<Results: AsyncSequence & Sendable>(
        _ results: Results,
        text: @escaping @Sendable (Results.Element) -> AttributedString
    ) -> Task<Void, Never> where Results.Element: Sendable & SpeechModuleResult {
        Task { @MainActor [weak self] in
            do {
                for try await result in results {
                    guard let self else { return }
                    let segment = String(text(result).characters)
                    if result.isFinal {
                        self.finalizedText += segment
                        self.transcribedText = self.finalizedText
                    } else {
                        self.transcribedText = self.finalizedText + segment
                    }
                }
            } catch {
                // Keep whatever was finalized, but record why the stream ended.
                DiagnosticLogger.shared.log("Apple: results stream ended with error: \(error)")
            }
        }
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let inputBuilder, let analyzerFormat else { return }
        guard let converted = convert(buffer, to: analyzerFormat) else { return }
        inputBuilder.yield(AnalyzerInput(buffer: converted))
    }

    func processAudioData(_ data: Data) {
        // Not used by Apple Speech — buffers are passed directly.
    }

    func stopTranscribing() async {
        inputBuilder?.finish()
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        // Finishing the analyzer ends the results stream; drain it so the final
        // segment is captured before teardown rather than cancelled mid-flight.
        await drainResults()

        analyzer = nil
        inputBuilder = nil
        converter = nil
        analyzerFormat = nil
        recognizerTask = nil
        isTranscribing = false
        startFailed = false
        didLogConversionFailure = false
    }

    /// Awaits the results task draining naturally, with a watchdog that cancels it
    /// if the stream never terminates (e.g. finalize threw).
    private func drainResults() async {
        guard let task = recognizerTask else { return }
        let watchdog = Task {
            try? await Task.sleep(for: .seconds(2))
            task.cancel()
        }
        await task.value
        watchdog.cancel()
    }

    // MARK: - Model assets

    /// Ensures the on-device model for `module`'s locale is installed, downloading
    /// it (with a preparing state) on first use. The locale is already resolved to a
    /// supported one before this is called.
    private func prepare(module: any SpeechModule) async throws {
        let status = await AssetInventory.status(forModules: [module])
        guard status != .installed else {
            diag.log("Apple: model already installed")
            return
        }

        onPreparingChanged?(true)
        defer { onPreparingChanged?(false) }
        diag.log("Apple: downloading language model (status: \(status))…")
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await request.downloadAndInstall()
            diag.log("Apple: language model download complete")
        } else {
            diag.log("Apple: no installation request needed")
        }
    }

    // MARK: - Audio conversion

    /// Converts a mic buffer (e.g. 48 kHz float) to the analyzer's preferred format,
    /// handling sample-rate changes via the block-based converter API.
    private func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }

        if converter == nil || converter?.outputFormat != format {
            converter = AVAudioConverter(from: buffer.format, to: format)
        }
        guard let converter else { return logConversionFailure("could not create converter") }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return logConversionFailure("could not allocate output buffer")
        }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil, output.frameLength > 0 else {
            return logConversionFailure("convert failed: \(error?.localizedDescription ?? "status \(status.rawValue)")")
        }
        return output
    }

    /// Logs an audio-conversion failure once per session (it would otherwise repeat
    /// for every buffer) and returns nil so the buffer is dropped.
    private func logConversionFailure(_ reason: String) -> AVAudioPCMBuffer? {
        if !didLogConversionFailure {
            didLogConversionFailure = true
            DiagnosticLogger.shared.log("Apple: dropping audio — \(reason)")
        }
        return nil
    }

    enum SpeechError: LocalizedError {
        case recognizerUnavailable
        case localeNotSupported(Locale)

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Speech recognition is not available on this device."
            case .localeNotSupported(let locale):
                let name = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
                return "\(name) isn't supported for on-device transcription."
            }
        }
    }
}
