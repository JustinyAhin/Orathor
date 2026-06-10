import AppKit
import AVFoundation
import Speech

/// Single source of truth for the three system permissions Orathor needs.
/// Views that show live status run `pollWhileVisible()` from a `.task {}` —
/// AXIsProcessTrusted has no change notification, so polling is the only way
/// to reflect a System Settings toggle without a relaunch.
@Observable
final class PermissionsService {
    enum Status {
        case granted
        case denied
        case notDetermined
    }

    private(set) var microphone: Status = .notDetermined
    private(set) var speechRecognition: Status = .notDetermined
    private(set) var accessibility = false

    var allGranted: Bool {
        microphone == .granted && speechRecognition == .granted && accessibility
    }

    func refresh() {
        microphone = Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
        speechRecognition = Self.map(SFSpeechRecognizer.authorizationStatus())
        accessibility = AXIsProcessTrusted()
    }

    func pollWhileVisible() async {
        while !Task.isCancelled {
            refresh()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func requestMicrophone() async {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        refresh()
    }

    func requestSpeechRecognition() async {
        _ = await AppleSpeechService.requestPermission()
        refresh()
    }

    /// The system Accessibility prompt only fires while the app isn't in the
    /// TCC list yet; after that the user must toggle it in System Settings.
    func promptAccessibility() {
        TextInsertionService.requestAccessibilityPermission()
        refresh()
    }

    static func openMicrophoneSettings() {
        openPrivacyPane("Privacy_Microphone")
    }

    static func openSpeechSettings() {
        openPrivacyPane("Privacy_SpeechRecognition")
    }

    static func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    private static func openPrivacyPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func map(_ status: AVAuthorizationStatus) -> Status {
        switch status {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    private static func map(_ status: SFSpeechRecognizerAuthorizationStatus) -> Status {
        switch status {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }
}
