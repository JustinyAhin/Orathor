import AudioToolbox

enum SoundService {
    private static let startSoundID: SystemSoundID = loadSound("Tink")
    private static let stopSoundID: SystemSoundID = loadSound("Pop")
    private static let cancelSoundID: SystemSoundID = loadSound("Funk")

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
