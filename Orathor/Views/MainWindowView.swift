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
                    .padding(Spacing.xxxl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case nil:
                Text("Select a section")
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.sm) {
                Text("Orathor")
                    .font(OType.captionMedium)
                    .foregroundStyle(Color.textTertiary)
                WaveformAccent(amplitude: 2, wavelength: 10, lineWidth: 1)
                    .frame(width: 60)
                    .opacity(0.4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)

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
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }
}
