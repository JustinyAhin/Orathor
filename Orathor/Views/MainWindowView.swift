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
                .toolbar(removing: .sidebarToggle)
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
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(SidebarGroup.allCases, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.title)
                            .font(OType.sidebarGroup)
                            .foregroundStyle(Color.textTertiary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.bottom, Spacing.xxs)

                        ForEach(group.sections) { section in
                            SidebarRow(
                                section: section,
                                isSelected: selectedSection == section
                            ) {
                                selectedSection = section
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.bottom, Spacing.md)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
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

private struct SidebarRow: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var background: Color {
        if isSelected { return .borderSubtle }
        return isHovered ? .borderSubtle.opacity(0.5) : .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: section.icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(section.title)
                    .font(OType.sidebarItem.weight(isSelected ? .medium : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(background)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
