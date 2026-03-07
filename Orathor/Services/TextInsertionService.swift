import AppKit
import Carbon.HIToolbox

struct TextInsertionService {
    struct FrontmostApp {
        let name: String
        let bundleIdentifier: String?
    }

    static func getFrontmostApp() -> FrontmostApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let name = app.localizedName ?? "Unknown"
        return FrontmostApp(name: name, bundleIdentifier: app.bundleIdentifier)
    }

    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func insertText(_ text: String) {
        let diag = DiagnosticLogger.shared
        let frontApp = NSWorkspace.shared.frontmostApplication
        diag.log("insertText called — text length: \(text.count), frontmost app: \(frontApp?.localizedName ?? "nil") (\(frontApp?.bundleIdentifier ?? "nil")), accessibility: \(AXIsProcessTrusted())")

        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let verifySet = pasteboard.string(forType: .string) == text
        diag.log("Clipboard set: \(verifySet)")

        simulatePaste()

        if let previousContents {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pasteboard.clearContents()
                pasteboard.setString(previousContents, forType: .string)
                diag.log("Clipboard restored")
            }
        }
    }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
