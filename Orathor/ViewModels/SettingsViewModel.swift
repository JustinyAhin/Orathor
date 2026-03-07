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
                insertHotkey = oldValue ?? .rightCommand
            }
            if let clipboardHotkey {
                UserDefaults.standard.set(clipboardHotkey.rawValue, forKey: "clipboardHotkey")
            } else {
                UserDefaults.standard.removeObject(forKey: "clipboardHotkey")
            }
            onHotkeyChanged?()
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

        let storedInsert = UserDefaults.standard.string(forKey: "insertHotkey") ?? HotkeyModifier.rightCommand.rawValue
        insertHotkey = HotkeyModifier(rawValue: storedInsert) ?? .rightCommand

        if let storedClipboard = UserDefaults.standard.string(forKey: "clipboardHotkey") {
            clipboardHotkey = HotkeyModifier(rawValue: storedClipboard)
        }
    }
}
