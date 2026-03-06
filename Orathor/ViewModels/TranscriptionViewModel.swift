import AppKit
import AVFoundation

@Observable
final class TranscriptionViewModel {
    var transcribedText = ""
    var isRecording = false
    var audioLevel: Float = 0
    var errorMessage: String?
    var hasPermission = false
    var hasAccessibility = false

    private let audioService = AudioService()
    private let speechService = AppleSpeechService()

    func checkPermissions() async {
        hasPermission = await AppleSpeechService.requestPermission()
        hasAccessibility = TextInsertionService.hasAccessibilityPermission
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard hasPermission else {
            errorMessage = "Speech recognition permission is required."
            return
        }

        do {
            transcribedText = ""
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
        audioLevel = 0
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
