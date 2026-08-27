import AppKit
import Foundation

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var appAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

@Observable
final class SettingsViewModel {
    var selectedEngine: SpeechEngine {
        didSet {
            AppPreferences.shared.set(selectedEngine.rawValue, forKey: "speechEngine")
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

    var openAIApiKey: String {
        didSet {
            if openAIApiKey.isEmpty {
                KeychainService.delete(key: "openaiApiKey")
            } else {
                KeychainService.save(key: "openaiApiKey", value: openAIApiKey)
            }
        }
    }

    var insertHotkey: HotkeyModifier {
        didSet {
            if let clipboardHotkey, insertHotkey == clipboardHotkey {
                self.clipboardHotkey = oldValue
            }
            AppPreferences.shared.set(insertHotkey.rawValue, forKey: "insertHotkey")
            onHotkeyChanged?()
        }
    }

    var clipboardHotkey: HotkeyModifier? {
        didSet {
            if let clipboardHotkey, clipboardHotkey == insertHotkey {
                insertHotkey = oldValue ?? .rightOption
            }
            if let clipboardHotkey {
                AppPreferences.shared.set(clipboardHotkey.rawValue, forKey: "clipboardHotkey")
            } else {
                AppPreferences.shared.removeObject(forKey: "clipboardHotkey")
            }
            onHotkeyChanged?()
        }
    }

    var startSound: String {
        didSet { AppPreferences.shared.set(startSound, forKey: "startSound") }
    }

    var stopSound: String {
        didSet { AppPreferences.shared.set(stopSound, forKey: "stopSound") }
    }

    var cancelSound: String {
        didSet { AppPreferences.shared.set(cancelSound, forKey: "cancelSound") }
    }

    var showInDock: Bool {
        didSet {
            AppPreferences.shared.set(showInDock, forKey: "showInDock")
            NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    var appearanceMode: AppearanceMode {
        didSet {
            AppPreferences.shared.set(appearanceMode.rawValue, forKey: "appearanceMode")
            NSApp.appearance = appearanceMode.appAppearance
        }
    }

    var transcriptionLanguage: String {
        didSet {
            AppPreferences.shared.set(transcriptionLanguage, forKey: "transcriptionLanguage")
            onTranscriptionLanguageChanged?()
        }
    }

    var smartFormattingEnabled: Bool {
        didSet {
            AppPreferences.shared.set(smartFormattingEnabled, forKey: "smartFormatting")
        }
    }

    var cloudVocabularyEnabled: Bool {
        didSet {
            AppPreferences.shared.set(cloudVocabularyEnabled, forKey: "cloudVocabularyEnabled")
        }
    }

    var onEngineChanged: ((SpeechEngine) -> Void)?
    var onHotkeyChanged: (() -> Void)?
    var onTranscriptionLanguageChanged: (() -> Void)?

    var isDeepgramConfigured: Bool {
        !deepgramApiKey.isEmpty
    }

    var isOpenAIConfigured: Bool {
        !openAIApiKey.isEmpty
    }

    init() {
        let stored = AppPreferences.shared.string(forKey: "speechEngine") ?? SpeechEngine.apple.rawValue
        selectedEngine = SpeechEngine(rawValue: stored) ?? .apple
        deepgramApiKey = KeychainService.load(key: "deepgramApiKey") ?? ""
        openAIApiKey = KeychainService.load(key: "openaiApiKey") ?? ""

        let storedInsert = AppPreferences.shared.string(forKey: "insertHotkey") ?? HotkeyModifier.rightOption.rawValue
        insertHotkey = HotkeyModifier(rawValue: storedInsert) ?? .rightOption

        if let storedClipboard = AppPreferences.shared.string(forKey: "clipboardHotkey") {
            clipboardHotkey = HotkeyModifier(rawValue: storedClipboard)
        }

        showInDock = AppPreferences.shared.object(forKey: "showInDock") as? Bool ?? false

        let storedAppearance = AppPreferences.shared.string(forKey: "appearanceMode") ?? AppearanceMode.dark.rawValue
        appearanceMode = AppearanceMode(rawValue: storedAppearance) ?? .dark

        transcriptionLanguage = AppPreferences.shared.string(forKey: "transcriptionLanguage") ?? "multi"
        smartFormattingEnabled = AppPreferences.shared.object(forKey: "smartFormatting") as? Bool ?? false
        cloudVocabularyEnabled = AppPreferences.shared.object(forKey: "cloudVocabularyEnabled") as? Bool ?? true

        startSound = AppPreferences.shared.string(forKey: "startSound") ?? SoundService.defaultStart
        stopSound = AppPreferences.shared.string(forKey: "stopSound") ?? SoundService.defaultStop
        cancelSound = AppPreferences.shared.string(forKey: "cancelSound") ?? SoundService.defaultCancel

        // Defer appearance so it doesn't interfere with MenuBarExtra setup
        let mode = appearanceMode
        DispatchQueue.main.async {
            NSApp.appearance = mode.appAppearance
        }
    }
}
