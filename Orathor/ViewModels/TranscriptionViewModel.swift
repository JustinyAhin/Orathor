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

    let settingsViewModel = SettingsViewModel()
    let historyService = TranscriptHistoryService()

    private let audioService = AudioService()
    private var speechService: any TranscriptionService
    private let keyboardService = KeyboardService()
    private var shouldAutoInsert = false
    private(set) var recordingMode: KeyboardService.RecordingMode = .insertAtCursor
    private var recordingStartTime: Date?
    private var targetApp: TextInsertionService.FrontmostApp?
    private var currentRecordingURL: URL?
    private var wasCancelled = false

    private var isSetUp = false
    private let diag = DiagnosticLogger.shared

    init() {
        speechService = TranscriptionViewModel.makeSpeechService(for: settingsViewModel.selectedEngine, apiKey: settingsViewModel.deepgramApiKey)
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
            self.speechService = TranscriptionViewModel.makeSpeechService(for: engine, apiKey: self.settingsViewModel.deepgramApiKey)
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
        } else {
            hasPermission = settingsViewModel.isDeepgramConfigured
        }
        hasAccessibility = TextInsertionService.hasAccessibilityPermission
    }

    private func configureSpeechServiceErrorHandler() {
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
            speechService = TranscriptionViewModel.makeSpeechService(for: .deepgram, apiKey: settingsViewModel.deepgramApiKey)
            configureSpeechServiceErrorHandler()
        }

        do {
            errorMessage = nil
            recordingStartTime = Date()
            targetApp = TextInsertionService.getFrontmostApp()
            diag.log("START recording — engine: \(engine), mode: \(recordingMode), targetApp: \(targetApp?.name ?? "nil") (\(targetApp?.bundleIdentifier ?? "nil")), shouldAutoInsert: \(shouldAutoInsert), accessibility: \(TextInsertionService.hasAccessibilityPermission)")

            audioService.onAudioBuffer = { [weak self] buffer, format in
                guard let self else { return }
                if !self.speechService.isTranscribing {
                    Task {
                        do {
                            try await self.speechService.startTranscribing(audioFormat: format)
                        } catch {
                            Task { @MainActor in
                                self.errorMessage = error.localizedDescription
                                await self.stopRecording()
                                self.scheduleErrorOverlayDismiss()
                            }
                        }
                    }
                }
                self.speechService.processAudioBuffer(buffer)
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
        audioService.stopRecording()
        // Let in-flight audio buffers reach Deepgram before sending Finalize
        try? await Task.sleep(for: .milliseconds(300))
        await speechService.stopTranscribing()
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

        let text = currentTranscription
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        diag.log("Transcription result — text length: \(text.count), mode: \(recordingMode), shouldAutoInsert: \(shouldAutoInsert), duration: \(String(format: "%.1f", duration))s")

        if !text.isEmpty {
            switch recordingMode {
            case .insertAtCursor:
                if shouldAutoInsert {
                    if TextInsertionService.hasAccessibilityPermission {
                        diag.log("Auto-inserting text at cursor")
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
                engine: settingsViewModel.selectedEngine
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

    private static func makeSpeechService(for engine: SpeechEngine, apiKey: String) -> any TranscriptionService {
        switch engine {
        case .apple:
            AppleSpeechService()
        case .deepgram:
            DeepgramService(apiKey: apiKey)
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
