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

    var onEngineChanged: ((SpeechEngine) -> Void)?

    var isDeepgramConfigured: Bool {
        !deepgramApiKey.isEmpty
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "speechEngine") ?? SpeechEngine.apple.rawValue
        selectedEngine = SpeechEngine(rawValue: stored) ?? .apple
        deepgramApiKey = KeychainService.load(key: "deepgramApiKey") ?? ""
    }
}
