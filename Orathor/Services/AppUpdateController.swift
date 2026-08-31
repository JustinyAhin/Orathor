#if SETAPP
import Combine

final class AppUpdateController: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    let isAvailable = false
    var automaticallyChecksForUpdates = false

    func checkForUpdates() {}
}
#else
import Combine
import Sparkle

final class AppUpdateController: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    let isAvailable = true

    private let updater: SPUUpdater

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
#endif
