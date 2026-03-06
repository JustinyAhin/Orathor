import AppKit

enum SoundService {
    static func playStart() {
        NSSound(named: "Tink")?.play()
    }

    static func playStop() {
        NSSound(named: "Pop")?.play()
    }
}
