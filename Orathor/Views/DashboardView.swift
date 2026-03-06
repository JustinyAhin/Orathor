import SwiftUI

struct DashboardView: View {
    let historyService: TranscriptHistoryService

    private var entries: [TranscriptEntry] { historyService.entries }

    private var totalWords: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }

    private var totalDuration: TimeInterval {
        entries.reduce(0) { $0 + $1.durationSeconds }
    }

    private var averageWPM: Double {
        let totalMinutes = totalDuration / 60
        guard totalMinutes > 0 else { return 0 }
        return Double(totalWords) / totalMinutes
    }

    var body: some View {
        if entries.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    statsStrip
                    recentSection
                }
                .padding(Spacing.xxxl)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            WaveformAccent(amplitude: 3, wavelength: 12, lineWidth: 1.5)
                .frame(width: 100)
                .opacity(0.4)
            Text("Ready to go")
                .font(OType.title)
                .foregroundStyle(Color.textPrimary)
            Text("Press your hotkey to start dictating")
                .font(OType.body)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stats

    private var statsStrip: some View {
        HStack(spacing: 0) {
            HomeStatItem(value: formattedCount(totalWords), label: "words", isHero: true)
            HomeStatItem(value: formattedDuration(totalDuration), label: "saved")
            HomeStatItem(value: String(format: "%.0f", averageWPM), label: "avg wpm")
        }
        .gradientAccentCard()
    }

    // MARK: - Recent Transcripts

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Recent")
                .sectionHeaderStyle()

            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(8).enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        SubtleDivider(leadingInset: Spacing.lg)
                    }
                    HomeTranscriptRow(entry: entry)
                }
            }
            .leftAccentCard(padding: 0)
        }
    }

    // MARK: - Helpers

    private func formattedCount(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))K"
                : String(format: "%.1fK", k)
        }
        return "\(count)"
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(totalSeconds)s"
        }
    }
}

// MARK: - Supporting Views

private struct HomeStatItem: View {
    let value: String
    let label: String
    var isHero: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            Text(value)
                .font(OType.stat)
                .foregroundStyle(
                    isHero
                        ? AnyShapeStyle(Color.brand)
                        : AnyShapeStyle(Color.textPrimary)
                )
            Text(label)
                .font(OType.captionMedium)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeTranscriptRow: View {
    let entry: TranscriptEntry

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            appIcon

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    if let appName = entry.targetAppName {
                        Text(appName)
                            .font(OType.captionMedium)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Text(entry.timestamp, format: .dateTime.hour().minute())
                        .font(OType.monoSmall)
                        .foregroundStyle(Color.textTertiary)
                    Text("\(entry.wordCount)w")
                        .font(OType.monoMicro)
                        .foregroundStyle(Color.textTertiary)
                }
                Text(entry.text)
                    .font(OType.body)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let bundleID = entry.targetAppBundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path()))
                .resizable()
                .frame(width: 16, height: 16)
                .padding(.top, 2)
        }
    }
}
