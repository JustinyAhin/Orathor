import SwiftUI

struct MainWindowView: View {
    var viewModel: TranscriptionViewModel
    @State private var selectedSection: AppSection = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            SubtleDivider()

            Group {
                switch selectedSection {
                case .dashboard:
                    DashboardView(historyService: viewModel.historyService)
                case .transcripts:
                    TranscriptsView(historyService: viewModel.historyService)
                case .settings:
                    ScrollView {
                        SettingsView(viewModel: viewModel.settingsViewModel)
                            .frame(maxWidth: 440)
                            .padding(.vertical, Spacing.xxxl)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var tabBar: some View {
        HStack {
            Spacer()

            HStack(spacing: Spacing.xxxs) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSection = section
                        }
                    } label: {
                        Label(section.title, systemImage: section.icon)
                            .font(OType.captionMedium)
                            .foregroundStyle(
                                selectedSection == section
                                    ? Color.textPrimary
                                    : Color.textTertiary
                            )
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .contentShape(Rectangle())
                            .background(
                                selectedSection == section
                                    ? Color.surfaceElevated
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: Radius.sm)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.xxxs)
            .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.md))

            Spacer()
        }
        .padding(.vertical, Spacing.sm)
    }
}
