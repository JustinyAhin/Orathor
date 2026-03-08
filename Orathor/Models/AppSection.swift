import SwiftUI

enum SidebarGroup: String, CaseIterable {
    case overview
    case monitor
    case settings

    var title: String {
        switch self {
        case .overview: "Overview"
        case .monitor: "Monitor"
        case .settings: "Settings"
        }
    }

    var sections: [AppSection] {
        switch self {
        case .overview: [.dashboard]
        case .monitor: [.transcripts]
        case .settings: [.settings]
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable, Hashable {
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
