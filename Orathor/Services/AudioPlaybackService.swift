import AVFoundation

@Observable
final class AudioPlaybackService {
    var isPlaying = false

    private var player: AVAudioPlayer?

    func play(url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = delegateHandler
            player?.play()
            isPlaying = true
        } catch {
            print("Audio playback failed: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    // AVAudioPlayerDelegate needs NSObject, so we use a helper
    private var _delegateHandler: DelegateHandler?
    private var delegateHandler: DelegateHandler {
        if let handler = _delegateHandler { return handler }
        let handler = DelegateHandler(service: self)
        _delegateHandler = handler
        return handler
    }
}

private class DelegateHandler: NSObject, AVAudioPlayerDelegate {
    weak var service: AudioPlaybackService?

    init(service: AudioPlaybackService) {
        self.service = service
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.service?.isPlaying = false
        }
    }
}
