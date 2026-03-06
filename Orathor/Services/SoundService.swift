import AudioToolbox

enum SoundService {
    private static let startSoundID: SystemSoundID = loadSound("Sosumi")
    private static let stopSoundID: SystemSoundID = loadSound("Purr")
    private static let cancelSoundID: SystemSoundID = loadSound("Morse")

    private static func loadSound(_ name: String) -> SystemSoundID {
        var soundID: SystemSoundID = 0
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        return soundID
    }

    static func playStart() {
        AudioServicesPlaySystemSound(startSoundID)
    }

    static func playStop() {
        AudioServicesPlaySystemSound(stopSoundID)
    }

    static func playCancel() {
        AudioServicesPlaySystemSound(cancelSoundID)
    }
}
