import AppKit
import AVFoundation
import Speech

@Observable
final class TranscriptionViewModel {
    var isRecording = false
    var errorMessage: String?
    var hasPermission = false
    var hasAccessibility = false

    let settingsViewModel = SettingsViewModel()

    private let audioService = AudioService()
    private var speechService: any TranscriptionService
    private let keyboardService = KeyboardService()
    private var shouldAutoInsert = false

    private var isSetUp = false

    init() {
        speechService = TranscriptionViewModel.makeSpeechService(for: settingsViewModel.selectedEngine, apiKey: settingsViewModel.deepgramApiKey)
    }

    func setUp() {
        guard !isSetUp else { return }
        isSetUp = true

        settingsViewModel.onEngineChanged = { [weak self] engine in
            guard let self, !self.isRecording else { return }
            self.speechService = TranscriptionViewModel.makeSpeechService(for: engine, apiKey: self.settingsViewModel.deepgramApiKey)
        }

        keyboardService.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .startRecording:
                self.shouldAutoInsert = true
                self.startRecording()
                RecordingOverlay.show(viewModel: self)
            case .stopRecording:
                Task {
                    await self.stopRecording()
                    RecordingOverlay.hide()
                }
            case .cancelRecording:
                self.shouldAutoInsert = false
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
        }

        do {
            errorMessage = nil

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
                            }
                        }
                    }
                }
                self.speechService.processAudioBuffer(buffer)
            }

            try audioService.startRecording()
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopRecording() async {
        audioService.stopRecording()
        // Let in-flight audio buffers reach Deepgram before sending Finalize
        try? await Task.sleep(for: .milliseconds(300))
        await speechService.stopTranscribing()
        isRecording = false

        if shouldAutoInsert {
            shouldAutoInsert = false
            let text = currentTranscription
            guard !text.isEmpty else { return }
            TextInsertionService.insertText(text)
        }
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
