#if SETAPP
import Setapp

enum SetappDistribution {
    static func configure() {
        SetappManager.shared.showReleaseNotesWindowIfNeeded()
    }

    static func reportUserInteraction() {
        SetappManager.shared.reportUsageEvent(.userInteraction)
    }
}
#else
enum SetappDistribution {
    static func configure() {}
    static func reportUserInteraction() {}
}
#endif
