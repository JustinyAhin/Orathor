import Sparkle
import SwiftUI

struct MainWindowView: View {
    var viewModel: TranscriptionViewModel
    let updater: SPUUpdater
    @State private var selectedSection: AppSection = .dashboard

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.surfacePrimary)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(SidebarGroup.allCases, id: \.self) { group in
                Section {
                    ForEach(group.sections) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                } header: {
                    Text(group.title)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(historyService: viewModel.historyService)
        case .transcripts:
            TranscriptsView(historyService: viewModel.historyService)
        case .settings:
            ScrollView {
                SettingsView(viewModel: viewModel.settingsViewModel, updater: updater)
                    .padding(Spacing.xxxl)
            }
        }
    }
}
