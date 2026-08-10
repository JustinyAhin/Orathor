import AppKit
import AVFoundation
import OrathorLicensing
import Speech

@Observable
final class TranscriptionViewModel {
    var isRecording = false
    var errorMessage: String?
    var hasPermission = false
    var hasAccessibility = false
    var needsAccessibilityPrompt = false
    var isPreparingModel = false
    var isFormatting = false

    let settingsViewModel = SettingsViewModel()
    let dictionaryService = PersonalDictionaryService()
    let historyService = TranscriptHistoryService()
    let permissions = PermissionsService()
    let license = LicenseManager()

    private let audioService = AudioService()
    private var speechService: any TranscriptionService
    private let keyboardService = KeyboardService()
    private let polisher = TranscriptPolisher()
    private let personalizer = TranscriptPersonalizer()
    private var shouldAutoInsert = false
    private(set) var recordingMode: KeyboardService.RecordingMode = .insertAtCursor
    private var recordingStartTime: Date?
    private var targetApp: TextInsertionService.FrontmostApp?
    private var currentRecordingURL: URL?
    private var wasCancelled = false
    private var pendingRecordingStartID: UUID?
    private var recordingDictionarySnapshot: PersonalDictionarySnapshot?

    private var isSetUp = false
    private let diag = DiagnosticLogger.shared
    private let recordingOverlay = RecordingOverlayController()

    init() {
        let dictionarySnapshot = dictionaryService.snapshot(
            cloudHintsEnabled: settingsViewModel.cloudVocabularyEnabled)
        let context = Self.makeContext(
            language: settingsViewModel.transcriptionLanguage,
            engine: settingsViewModel.selectedEngine,
            dictionary: dictionarySnapshot)
        let config = SpeechServiceConfig(
            engine: settingsViewModel.selectedEngine,
            deepgramAPIKey: settingsViewModel.deepgramApiKey,
            openAIAPIKey: settingsViewModel.openAIApiKey,
            language: settingsViewModel.transcriptionLanguage,
            context: context,
            openAITranscriptionDelay: UserDefaults.standard.string(forKey: "whisperTranscriptionDelay") ?? "low"
        )
        speechServiceConfig = config
        speechService = TranscriptionViewModel.makeSpeechService(
            for: config.engine,
            deepgramAPIKey: config.deepgramAPIKey,
            openAIAPIKey: config.openAIAPIKey,
            language: config.language,
            context: config.context,
            openAITranscriptionDelay: config.openAITranscriptionDelay
        )
        configureSpeechServiceErrorHandler()
        guard !AppRuntime.isRunningTests else { return }
        DispatchQueue.main.async { [self] in self.setUp() }
    }

    private var speechServiceConfig: SpeechServiceConfig

    /// Keeps the cached service (and any warm connection it holds) unless
    /// engine, API key, or language changed since it was built.
    private func refreshSpeechServiceIfNeeded(dictionary: PersonalDictionarySnapshot? = nil) {
        let dictionary = dictionary ?? dictionaryService.snapshot(
            cloudHintsEnabled: settingsViewModel.cloudVocabularyEnabled)
        let context = Self.makeContext(
            language: settingsViewModel.transcriptionLanguage,
            engine: settingsViewModel.selectedEngine,
            dictionary: dictionary)
        let config = SpeechServiceConfig(
            engine: settingsViewModel.selectedEngine,
            deepgramAPIKey: settingsViewModel.deepgramApiKey,
            openAIAPIKey: settingsViewModel.openAIApiKey,
            language: settingsViewModel.transcriptionLanguage,
            context: context,
            openAITranscriptionDelay: UserDefaults.standard.string(forKey: "whisperTranscriptionDelay") ?? "low"
        )
        guard config != speechServiceConfig else { return }
        speechService.shutdown()
        speechService = TranscriptionViewModel.makeSpeechService(
            for: config.engine,
            deepgramAPIKey: config.deepgramAPIKey,
            openAIAPIKey: config.openAIAPIKey,
            language: config.language,
            context: config.context,
            openAITranscriptionDelay: config.openAITranscriptionDelay
        )
        speechServiceConfig = config
        configureSpeechServiceErrorHandler()
    }

    func setUp() {
        guard !isSetUp else { return }
        isSetUp = true

        Task { await license.refresh() }

        settingsViewModel.onEngineChanged = { [weak self] _ in
            guard let self, !self.isRecording else { return }
            self.refreshSpeechServiceIfNeeded()
        }

        keyboardService.insertHotkey = settingsViewModel.insertHotkey
        keyboardService.clipboardHotkey = settingsViewModel.clipboardHotkey

        settingsViewModel.onHotkeyChanged = { [weak self] in
            guard let self else { return }
            self.keyboardService.insertHotkey = self.settingsViewModel.insertHotkey
            self.keyboardService.clipboardHotkey = self.settingsViewModel.clipboardHotkey
        }

        keyboardService.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .startRecording(let mode):
                self.needsAccessibilityPrompt = false
                self.recordingMode = mode
                self.shouldAutoInsert = (mode == .insertAtCursor)
                let startID = UUID()
                self.pendingRecordingStartID = startID
                self.recordingOverlay.present(sessionID: startID, viewModel: self)
                Task {
                    await self.startRecording(startID: startID)
                    if !self.isRecording, let message = self.errorMessage {
                        self.presentOverlayError(message, sessionID: startID)
                    }
                }
            case .stopRecording:
                let sessionID = self.recordingOverlay.currentSessionID
                Task {
                    await self.stopRecording()
                    if self.needsAccessibilityPrompt, let sessionID {
                        self.recordingOverlay.update(
                            mode: .accessibilityPrompt,
                            sessionID: sessionID
                        )
                        self.recordingOverlay.dismiss(
                            after: .seconds(8),
                            sessionID: sessionID,
                            onDismiss: { [weak self] in
                                self?.needsAccessibilityPrompt = false
                            }
                        )
                    } else {
                        self.recordingOverlay.dismiss(sessionID: sessionID)
                    }
                }
            case .cancelRecording:
                self.shouldAutoInsert = false
                self.wasCancelled = true
                let sessionID = self.recordingOverlay.currentSessionID
                Task {
                    await self.stopRecording()
                    self.recordingOverlay.dismiss(sessionID: sessionID)
                }
            }
        }
        keyboardService.start()
    }

    /// Non-prompting status reads — the onboarding flow (or `startRecording`'s
    /// on-demand fallback) owns the actual permission requests.
    func checkPermissions() async {
        permissions.refresh()
        if settingsViewModel.selectedEngine == .apple {
            hasPermission = permissions.speechRecognition == .granted
        } else if settingsViewModel.selectedEngine == .deepgram {
            hasPermission = settingsViewModel.isDeepgramConfigured
        } else {
            hasPermission = settingsViewModel.isOpenAIConfigured
        }
        hasAccessibility = permissions.accessibility
    }

    private func configureSpeechServiceErrorHandler() {
        if let apple = speechService as? AppleSpeechService {
            apple.onPreparingChanged = { [weak self] preparing in
                Task { @MainActor in
                    guard let self else { return }
                    self.isPreparingModel = preparing
                    guard let sessionID = self.recordingOverlay.currentSessionID else { return }
                    if preparing {
                        self.recordingOverlay.update(mode: .preparing, sessionID: sessionID)
                    } else if self.isRecording {
                        self.recordingOverlay.update(mode: .recording, sessionID: sessionID)
                    } else if self.pendingRecordingStartID != nil {
                        self.recordingOverlay.update(mode: .starting, sessionID: sessionID)
                    }
                }
            }
        }
        if let deepgram = speechService as? DeepgramService {
            deepgram.onError = { [weak self] message in
                Task { @MainActor in
                    guard let self else { return }
                    let sessionID = self.recordingOverlay.currentSessionID
                    await self.stopRecording()
                    self.presentOverlayError(message, sessionID: sessionID)
                }
            }
        }
        if let openAI = speechService as? OpenAIRealtimeTranscriptionService {
            openAI.onError = { [weak self] message in
                Task { @MainActor in
                    guard let self else { return }
                    let sessionID = self.recordingOverlay.currentSessionID
                    await self.stopRecording()
                    self.presentOverlayError(message, sessionID: sessionID)
                }
            }
        }
    }

    func dismissAccessibilityPrompt() {
        needsAccessibilityPrompt = false
        recordingOverlay.dismiss()
    }

    private func presentOverlayError(_ message: String, sessionID: UUID?) {
        if let sessionID, recordingOverlay.currentSessionID != sessionID {
            return
        }
        errorMessage = message
        guard let sessionID else { return }
        recordingOverlay.update(mode: .error(message), sessionID: sessionID)
        recordingOverlay.dismiss(after: .seconds(3), sessionID: sessionID)
    }

    func toggleRecording() {
        if isRecording {
            shouldAutoInsert = false
            Task { await stopRecording() }
        } else {
            let startID = UUID()
            pendingRecordingStartID = startID
            Task { await startRecording(startID: startID) }
        }
    }

    private func startRecording(startID: UUID) async {
        await license.refresh()
        guard pendingRecordingStartID == startID else { return }

        guard license.canDictate else {
            pendingRecordingStartID = nil
            errorMessage = license.state == .trialExpired
                ? "Your free trial has ended. Enter a license key in Settings to keep dictating."
                : "Your license could not be validated. Check Settings."
            return
        }

        let engine = settingsViewModel.selectedEngine

        if engine == .apple {
            if !hasPermission {
                let status = SFSpeechRecognizer.authorizationStatus()
                if status == .authorized {
                    hasPermission = true
                } else if status == .notDetermined {
                    hasPermission = await AppleSpeechService.requestPermission()
                    guard pendingRecordingStartID == startID else { return }
                } else {
                    pendingRecordingStartID = nil
                    errorMessage = "Speech recognition permission is required."
                    return
                }
                guard hasPermission else {
                    pendingRecordingStartID = nil
                    errorMessage = "Speech recognition permission is required."
                    return
                }
            }
        } else if engine == .deepgram {
            guard settingsViewModel.isDeepgramConfigured else {
                pendingRecordingStartID = nil
                errorMessage = "Deepgram API key is required. Add it in Settings."
                return
            }
        } else if engine == .openAIWhisper {
            guard settingsViewModel.isOpenAIConfigured else {
                pendingRecordingStartID = nil
                errorMessage = "OpenAI API key is required. Add it in Settings."
                return
            }
        }

        guard pendingRecordingStartID == startID else { return }
        let dictionarySnapshot = dictionaryService.snapshot(
            cloudHintsEnabled: settingsViewModel.cloudVocabularyEnabled)
        recordingDictionarySnapshot = dictionarySnapshot
        refreshSpeechServiceIfNeeded(dictionary: dictionarySnapshot)

        do {
            errorMessage = nil
            recordingStartTime = Date()
            targetApp = TextInsertionService.getFrontmostApp()
            diag.log("START recording — engine: \(engine), mode: \(recordingMode), targetApp: \(targetApp?.name ?? "nil") (\(targetApp?.bundleIdentifier ?? "nil")), shouldAutoInsert: \(shouldAutoInsert), accessibility: \(TextInsertionService.hasAccessibilityPermission)")

            audioService.onAudioBuffer = { [weak self] buffer, _ in
                self?.speechService.processAudioBuffer(buffer)
            }

            // Connect on key-down so the WS handshake overlaps audio engine
            // spin-up; audio arriving mid-handshake queues inside the service.
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.speechService.startTranscribing()
                } catch {
                    await self.stopRecording()
                    self.presentOverlayError(error.localizedDescription, sessionID: startID)
                }
            }

            currentRecordingURL = historyService.newRecordingURL()
            try audioService.startRecording(saveTo: currentRecordingURL)
            isRecording = true
            pendingRecordingStartID = nil
            recordingOverlay.update(
                mode: isPreparingModel ? .preparing : .recording,
                sessionID: startID
            )
        } catch {
            pendingRecordingStartID = nil
            recordingDictionarySnapshot = nil
            errorMessage = error.localizedDescription
        }
    }

    private func stopRecording() async {
        pendingRecordingStartID = nil
        diag.log("STOP recording — wasCancelled: \(wasCancelled)")
        let stopStart = Date()
        // No flush delay needed: removeTap is synchronous and all audio is
        // enqueued on the socket before Finalize/commit, so ordering holds.
        audioService.stopRecording()
        await speechService.stopTranscribing()
        diag.log("Stop: engine finalized \(Int(Date().timeIntervalSince(stopStart) * 1000))ms after key-up")
        isRecording = false

        let cancelled = wasCancelled
        wasCancelled = false

        // On cancel, discard audio and skip saving
        if cancelled {
            diag.log("Recording cancelled, discarding")
            if let url = currentRecordingURL {
                try? FileManager.default.removeItem(at: url)
            }
            recordingStartTime = nil
            targetApp = nil
            currentRecordingURL = nil
            recordingDictionarySnapshot = nil
            return
        }

        var text = currentTranscription
        let rawText = text
        let dictionary = recordingDictionarySnapshot ?? dictionaryService.snapshot(
            cloudHintsEnabled: settingsViewModel.cloudVocabularyEnabled)
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // Optional on-device cleanup pass (Foundation Models). Fails open to raw text.
        var didPolish = false
        if settingsViewModel.smartFormattingEnabled, !text.isEmpty {
            let raw = text
            isFormatting = true
            if let sessionID = recordingOverlay.currentSessionID {
                recordingOverlay.update(mode: .formatting, sessionID: sessionID)
            }
            text = await polisher.polish(text, dictionary: dictionary)
            isFormatting = false
            didPolish = text != raw
            diag.log("Smart formatting — applied: \(settingsViewModel.smartFormattingEnabled), changed: \(didPolish) (\(raw.count) → \(text.count) chars)")
        }

        let beforePersonalization = text
        text = personalizer.personalize(text, using: dictionary)
        let didPersonalize = text != beforePersonalization
        let originalText = text != rawText ? rawText : nil
        diag.log("Personal dictionary — terms: \(dictionary.terms.count), rules: \(dictionary.replacements.count), changed: \(didPersonalize)")

        diag.log("Transcription result — text length: \(text.count), mode: \(recordingMode), shouldAutoInsert: \(shouldAutoInsert), duration: \(String(format: "%.1f", duration))s")

        if !text.isEmpty {
            switch recordingMode {
            case .insertAtCursor:
                if shouldAutoInsert {
                    if TextInsertionService.hasAccessibilityPermission {
                        diag.log("Auto-inserting text at cursor \(Int(Date().timeIntervalSince(stopStart) * 1000))ms after key-up")
                        TextInsertionService.insertText(text)
                    } else {
                        diag.log("No accessibility permission — copying to clipboard as fallback")
                        TextInsertionService.copyToClipboard(text)
                        needsAccessibilityPrompt = true
                    }
                } else {
                    diag.log("SKIPPED insertion — shouldAutoInsert is false")
                }
            case .clipboard:
                diag.log("Copying to clipboard")
                TextInsertionService.copyToClipboard(text)
            }
        } else {
            diag.log("SKIPPED insertion — text is empty")
        }
        shouldAutoInsert = false
        recordingMode = .insertAtCursor

        if !text.isEmpty {
            let entry = TranscriptEntry(
                text: text,
                timestamp: Date(),
                durationSeconds: duration,
                wordCount: text.split(separator: " ").count,
                targetAppName: targetApp?.name,
                targetAppBundleID: targetApp?.bundleIdentifier,
                audioFileName: currentRecordingURL?.lastPathComponent,
                engine: settingsViewModel.selectedEngine,
                smartFormatted: didPolish,
                rawText: originalText,
                formattingModel: didPolish ? TranscriptPolisher.modelDescription : nil
            )
            historyService.add(entry)
        } else if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        recordingStartTime = nil
        targetApp = nil
        currentRecordingURL = nil
        recordingDictionarySnapshot = nil
    }

    var currentAudioLevel: AudioMeterLevel {
        audioService.audioLevel
    }

    var currentTranscription: String {
        speechService.transcribedText
    }

    private static func makeSpeechService(
        for engine: SpeechEngine,
        deepgramAPIKey: String,
        openAIAPIKey: String,
        language: String = "multi",
        context: TranscriptionContext = TranscriptionContext(),
        openAITranscriptionDelay: String = "low"
    ) -> any TranscriptionService {
        switch engine {
        case .apple:
            AppleSpeechService()
        case .deepgram:
            DeepgramService(apiKey: deepgramAPIKey, language: language, context: context)
        case .openAIWhisper:
            OpenAIRealtimeTranscriptionService(
                apiKey: openAIAPIKey, context: context, delay: openAITranscriptionDelay)
        }
    }

    private static func makeContext(
        language: String,
        engine: SpeechEngine,
        dictionary: PersonalDictionarySnapshot
    ) -> TranscriptionContext {
        let keywords: [String]
        switch engine {
        case .apple:
            keywords = []
        case .deepgram:
            keywords = dictionary.cloudKeywords
        case .openAIWhisper:
            keywords = dictionary.cloudKeywords.filter {
                !$0.contains("<") && !$0.contains(">") && !$0.contains("\r") && !$0.contains("\n")
            }
            let omittedCount = dictionary.cloudKeywords.count - keywords.count
            if omittedCount > 0 {
                DiagnosticLogger.shared.log(
                    "OpenAI vocabulary hints — omitted \(omittedCount) incompatible terms")
            }
        }
        return TranscriptionContext(
            keywords: keywords,
            languages: TranscriptionContext.fromLegacyLanguage(language).languages)
    }

    func insertAtCursor() {
        let text = currentTranscription
        guard !text.isEmpty else { return }

        if !hasAccessibility {
            TextInsertionService.requestAccessibilityPermission()
            hasAccessibility = TextInsertionService.hasAccessibilityPermission
            return
        }

        if isRecording {
            shouldAutoInsert = false
            Task {
                await stopRecording()
                NSApp.deactivate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    TextInsertionService.insertText(text)
                }
            }
            return
        }

        NSApp.deactivate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            TextInsertionService.insertText(text)
        }
    }

    func copyToClipboard() {
        let text = currentTranscription
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
