import SwiftUI

struct MainWindowView: View {
    var viewModel: TranscriptionViewModel
    @State private var selectedSection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            switch selectedSection {
            case .dashboard:
                DashboardView(historyService: viewModel.historyService)
            case .transcripts:
                TranscriptsView(historyService: viewModel.historyService)
            case .settings:
                SettingsView(viewModel: viewModel.settingsViewModel)
                    .navigationTitle("Settings")
                    .frame(maxWidth: 500, alignment: .leading)
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case nil:
                Text("Select a section")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // App branding
            VStack(spacing: 4) {
                Image(systemName: "waveform")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                Text("Orathor")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)

            Divider()
                .padding(.horizontal, 16)

            // Main nav
            List(selection: $selectedSection) {
                ForEach(AppSection.allCases.filter { $0 != .settings }) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }

                Section {
                    Label(AppSection.settings.title, systemImage: AppSection.settings.icon)
                        .tag(AppSection.settings)
                }
            }
            .listStyle(.sidebar)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
    }
}
