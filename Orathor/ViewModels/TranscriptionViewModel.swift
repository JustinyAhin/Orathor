import AppKit
import AVFoundation
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
    let historyService = TranscriptHistoryService()

    private let audioService = AudioService()
    private var speechService: any TranscriptionService
    private let keyboardService = KeyboardService()
    private let polisher = TranscriptPolisher()
    private var shouldAutoInsert = false
    private(set) var recordingMode: KeyboardService.RecordingMode = .insertAtCursor
    private var recordingStartTime: Date?
    private var targetApp: TextInsertionService.FrontmostApp?
    private var currentRecordingURL: URL?
    private var wasCancelled = false

    private var isSetUp = false
    private let diag = DiagnosticLogger.shared

    init() {
        speechService = TranscriptionViewModel.makeSpeechService(
            for: settingsViewModel.selectedEngine,
            deepgramApiKey: settingsViewModel.deepgramApiKey,
            openAIApiKey: settingsViewModel.openAIApiKey,
            language: settingsViewModel.transcriptionLanguage
        )
        configureSpeechServiceErrorHandler()
        DispatchQueue.main.async { [self] in
            self.setUp()
        }
    }

    func setUp() {
        guard !isSetUp else { return }
        isSetUp = true

        settingsViewModel.onEngineChanged = { [weak self] engine in
            guard let self, !self.isRecording else { return }
            self.speechService = TranscriptionViewModel.makeSpeechService(
                for: engine,
                deepgramApiKey: self.settingsViewModel.deepgramApiKey,
                openAIApiKey: self.settingsViewModel.openAIApiKey,
                language: self.settingsViewModel.transcriptionLanguage
            )
            self.configureSpeechServiceErrorHandler()
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
                self.recordingMode = mode
                self.shouldAutoInsert = (mode == .insertAtCursor)
                self.startRecording()
                RecordingOverlay.show(viewModel: self)
                if !self.isRecording, self.errorMessage != nil {
                    self.scheduleErrorOverlayDismiss()
                }
            case .stopRecording:
                Task {
                    await self.stopRecording()
                    if self.needsAccessibilityPrompt {
                        self.scheduleAccessibilityPromptDismiss()
                    } else {
                        RecordingOverlay.hide()
                    }
                }
            case .cancelRecording:
                self.shouldAutoInsert = false
                self.wasCancelled = true
                Task {
                    await self.stopRecording()
                    RecordingOverlay.hide()
                }
            }
        }
        keyboardService.start()
    }

    func checkPermissions() async {
        if settingsViewModel.selectedEngine == .apple {
            hasPermission = await AppleSpeechService.requestPermission()
        } else if settingsViewModel.selectedEngine == .deepgram {
            hasPermission = settingsViewModel.isDeepgramConfigured
        } else {
            hasPermission = settingsViewModel.isOpenAIConfigured
        }
        hasAccessibility = TextInsertionService.hasAccessibilityPermission
    }

    private func configureSpeechServiceErrorHandler() {
        if let apple = speechService as? AppleSpeechService {
            apple.onPreparingChanged = { [weak self] preparing in
                Task { @MainActor in
                    self?.isPreparingModel = preparing
                }
            }
        }
        if let deepgram = speechService as? DeepgramService {
            deepgram.onError = { [weak self] message in
                Task { @MainActor in
                    guard let self else { return }
                    self.errorMessage = message
                    await self.stopRecording()
                    self.scheduleErrorOverlayDismiss()
                }
            }
        }
        if let openAI = speechService as? OpenAIRealtimeWhisperService {
            openAI.onError = { [weak self] message in
                Task { @MainActor in
                    guard let self else { return }
                    self.errorMessage = message
                    await self.stopRecording()
                    self.scheduleErrorOverlayDismiss()
                }
            }
        }
    }

    func dismissAccessibilityPrompt() {
        needsAccessibilityPrompt = false
        RecordingOverlay.hide()
    }

    private func scheduleAccessibilityPromptDismiss() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            if self.needsAccessibilityPrompt {
                dismissAccessibilityPrompt()
            }
        }
    }

    private func scheduleErrorOverlayDismiss() {
        let msg = errorMessage
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if self.errorMessage == msg, !self.isRecording {
                RecordingOverlay.hide()
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            shouldAutoInsert = false
            Task { await stopRecording() }
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let engine = settingsViewModel.selectedEngine

        if engine == .apple {
            if !hasPermission {
                let status = SFSpeechRecognizer.authorizationStatus()
                if status == .authorized {
                    hasPermission = true
                } else if status == .notDetermined {
                    Task {
                        hasPermission = await AppleSpeechService.requestPermission()
                        if hasPermission { startRecording() }
                    }
                    return
                } else {
                    errorMessage = "Speech recognition permission is required."
                    return
                }
            }
        } else if engine == .deepgram {
            guard settingsViewModel.isDeepgramConfigured else {
                errorMessage = "Deepgram API key is required. Add it in Settings."
                return
            }
            // Recreate service with current API key in case it changed
            speechService = TranscriptionViewModel.makeSpeechService(
                for: .deepgram,
                deepgramApiKey: settingsViewModel.deepgramApiKey,
                openAIApiKey: settingsViewModel.openAIApiKey,
                language: settingsViewModel.transcriptionLanguage
            )
            configureSpeechServiceErrorHandler()
        } else if engine == .openAIWhisper {
            guard settingsViewModel.isOpenAIConfigured else {
                errorMessage = "OpenAI API key is required. Add it in Settings."
                return
            }
            // Recreate service with current API key in case it changed
            speechService = TranscriptionViewModel.makeSpeechService(
                for: .openAIWhisper,
                deepgramApiKey: settingsViewModel.deepgramApiKey,
                openAIApiKey: settingsViewModel.openAIApiKey,
                language: settingsViewModel.transcriptionLanguage
            )
            configureSpeechServiceErrorHandler()
        }

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
                    self.errorMessage = error.localizedDescription
                    await self.stopRecording()
                    self.scheduleErrorOverlayDismiss()
                }
            }

            currentRecordingURL = historyService.newRecordingURL()
            try audioService.startRecording(saveTo: currentRecordingURL)
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopRecording() async {
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
            return
        }

        var text = currentTranscription
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // Optional on-device cleanup pass (Foundation Models). Fails open to raw text.
        var didPolish = false
        var originalText: String?
        if settingsViewModel.smartFormattingEnabled, !text.isEmpty {
            let raw = text
            isFormatting = true
            text = await polisher.polish(text)
            isFormatting = false
            didPolish = text != raw
            if didPolish { originalText = raw }
            diag.log("Smart formatting — applied: \(settingsViewModel.smartFormattingEnabled), changed: \(didPolish) (\(raw.count) → \(text.count) chars)")
        }

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
    }

    var currentAudioLevel: Float {
        audioService.audioLevel
    }

    var currentTranscription: String {
        speechService.transcribedText
    }

    private static func makeSpeechService(
        for engine: SpeechEngine,
        deepgramApiKey: String,
        openAIApiKey: String,
        language: String = "multi"
    ) -> any TranscriptionService {
        switch engine {
        case .apple:
            AppleSpeechService()
        case .deepgram:
            DeepgramService(apiKey: deepgramApiKey, language: language)
        case .openAIWhisper:
            OpenAIRealtimeWhisperService(apiKey: openAIApiKey, language: language)
        }
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
