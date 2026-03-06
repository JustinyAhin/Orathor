import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case transcripts
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Home"
        case .transcripts: "Transcripts"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "waveform"
        case .transcripts: "text.quote"
        case .settings: "gearshape"
        }
    }
}
