import AppKit
import Foundation

@Observable
final class SettingsViewModel {
    var selectedEngine: SpeechEngine {
        didSet {
            UserDefaults.standard.set(selectedEngine.rawValue, forKey: "speechEngine")
            onEngineChanged?(selectedEngine)
        }
    }

    var deepgramApiKey: String {
        didSet {
            if deepgramApiKey.isEmpty {
                KeychainService.delete(key: "deepgramApiKey")
            } else {
                KeychainService.save(key: "deepgramApiKey", value: deepgramApiKey)
            }
        }
    }

    var insertHotkey: HotkeyModifier {
        didSet {
            if let clipboardHotkey, insertHotkey == clipboardHotkey {
                self.clipboardHotkey = oldValue
            }
            UserDefaults.standard.set(insertHotkey.rawValue, forKey: "insertHotkey")
            onHotkeyChanged?()
        }
    }

    var clipboardHotkey: HotkeyModifier? {
        didSet {
            if let clipboardHotkey, clipboardHotkey == insertHotkey {
                insertHotkey = oldValue ?? .rightOption
            }
            if let clipboardHotkey {
                UserDefaults.standard.set(clipboardHotkey.rawValue, forKey: "clipboardHotkey")
            } else {
                UserDefaults.standard.removeObject(forKey: "clipboardHotkey")
            }
            onHotkeyChanged?()
        }
    }

    var startSound: String {
        didSet { UserDefaults.standard.set(startSound, forKey: "startSound") }
    }

    var stopSound: String {
        didSet { UserDefaults.standard.set(stopSound, forKey: "stopSound") }
    }

    var cancelSound: String {
        didSet { UserDefaults.standard.set(cancelSound, forKey: "cancelSound") }
    }

    var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    var onEngineChanged: ((SpeechEngine) -> Void)?
    var onHotkeyChanged: (() -> Void)?

    var isDeepgramConfigured: Bool {
        !deepgramApiKey.isEmpty
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "speechEngine") ?? SpeechEngine.apple.rawValue
        selectedEngine = SpeechEngine(rawValue: stored) ?? .apple
        deepgramApiKey = KeychainService.load(key: "deepgramApiKey") ?? ""

        let storedInsert = UserDefaults.standard.string(forKey: "insertHotkey") ?? HotkeyModifier.rightOption.rawValue
        insertHotkey = HotkeyModifier(rawValue: storedInsert) ?? .rightOption

        if let storedClipboard = UserDefaults.standard.string(forKey: "clipboardHotkey") {
            clipboardHotkey = HotkeyModifier(rawValue: storedClipboard)
        }

        showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? false

        startSound = UserDefaults.standard.string(forKey: "startSound") ?? SoundService.defaultStart
        stopSound = UserDefaults.standard.string(forKey: "stopSound") ?? SoundService.defaultStop
        cancelSound = UserDefaults.standard.string(forKey: "cancelSound") ?? SoundService.defaultCancel
    }
}
