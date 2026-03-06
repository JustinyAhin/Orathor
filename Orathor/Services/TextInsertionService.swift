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

    static func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulatePaste()

        if let previousContents {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pasteboard.clearContents()
                pasteboard.setString(previousContents, forType: .string)
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
