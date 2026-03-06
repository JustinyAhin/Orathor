import AppKit
import AVFoundation
import Speech

@Observable
final class TranscriptionViewModel {
    var isRecording = false
    var errorMessage: String?
    var hasPermission = false
    var hasAccessibility = false

    private let audioService = AudioService()
    private let speechService = AppleSpeechService()
    private let keyboardService = KeyboardService()
    private var shouldAutoInsert = false

    private var isSetUp = false

    func setUp() {
        guard !isSetUp else { return }
        isSetUp = true

        keyboardService.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .startRecording:
                SoundService.playStart()
                self.shouldAutoInsert = true
                self.startRecording()
                RecordingOverlay.show(viewModel: self)
            case .stopRecording:
                SoundService.playStop()
                self.stopRecording()
                RecordingOverlay.hide()
            case .cancelRecording:
                SoundService.playStop()
                self.shouldAutoInsert = false
                self.stopRecording()
                RecordingOverlay.hide()
            }
        }
        keyboardService.start()
    }

    func checkPermissions() async {
        hasPermission = await AppleSpeechService.requestPermission()
        hasAccessibility = TextInsertionService.hasAccessibilityPermission
    }

    func toggleRecording() {
        if isRecording {
            shouldAutoInsert = false
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // Check permission synchronously if not yet resolved
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

        do {
            errorMessage = nil

            audioService.onAudioBuffer = { [weak self] buffer, format in
                guard let self else { return }
                if !self.speechService.isTranscribing {
                    try? self.speechService.startTranscribing(audioFormat: format)
                }
                self.speechService.processAudioBuffer(buffer)
            }

            try audioService.startRecording()
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopRecording() {
        audioService.stopRecording()
        speechService.stopTranscribing()
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
            stopRecording()
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
