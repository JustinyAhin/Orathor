import AudioToolbox

enum SoundService {
    static let defaultStart = "Funk"
    static let defaultStop = "Submarine"
    static let defaultCancel = "Basso"

    static let availableSounds: [String] = {
        let url = URL(fileURLWithPath: "/System/Library/Sounds")
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "aiff" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }()

    private static var cache: [String: SystemSoundID] = [:]

    private static func soundID(for name: String) -> SystemSoundID {
        if let cached = cache[name] { return cached }
        var soundID: SystemSoundID = 0
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        cache[name] = soundID
        return soundID
    }

    private static func soundName(forKey key: String, default defaultName: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? defaultName
    }

    static func playStart() {
        let name = soundName(forKey: "startSound", default: defaultStart)
        AudioServicesPlaySystemSound(soundID(for: name))
    }

    static func playStop() {
        let name = soundName(forKey: "stopSound", default: defaultStop)
        AudioServicesPlaySystemSound(soundID(for: name))
    }

    static func playCancel() {
        let name = soundName(forKey: "cancelSound", default: defaultCancel)
        AudioServicesPlaySystemSound(soundID(for: name))
    }

    static func preview(_ name: String) {
        AudioServicesPlaySystemSound(soundID(for: name))
    }
}
