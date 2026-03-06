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

    private var topSources: [(name: String, bundleID: String?, wordCount: Int)] {
        var byApp: [String: (bundleID: String?, words: Int)] = [:]
        for entry in entries {
            let name = entry.targetAppName ?? "Unknown"
            let existing = byApp[name, default: (bundleID: entry.targetAppBundleID, words: 0)]
            byApp[name] = (bundleID: existing.bundleID ?? entry.targetAppBundleID, words: existing.words + entry.wordCount)
        }
        return byApp
            .map { (name: $0.key, bundleID: $0.value.bundleID, wordCount: $0.value.words) }
            .sorted { $0.wordCount > $1.wordCount }
            .prefix(5)
            .map { $0 }
    }

    private var activityData: ActivityGrid {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dailyCounts: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            dailyCounts[day, default: 0] += entry.wordCount
        }

        let todayWeekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (todayWeekday + 5) % 7
        let weeksToShow = 4
        let totalDayCount = weeksToShow * 7
        let gridStart = calendar.date(byAdding: .day, value: -(totalDayCount - 1 - (6 - daysSinceMonday)), to: today)!

        var days: [ActivityDay] = []
        for i in 0..<totalDayCount {
            let date = calendar.date(byAdding: .day, value: i, to: gridStart)!
            let count = dailyCounts[date] ?? 0
            let isFuture = date > today
            days.append(ActivityDay(date: date, wordCount: count, isFuture: isFuture))
        }

        let maxCount = days.map(\.wordCount).max() ?? 0
        let activeDays = dailyCounts.keys.count

        return ActivityGrid(days: days, maxCount: maxCount, activeDays: activeDays)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                statsSection
                HStack(alignment: .top, spacing: Spacing.xxl) {
                    topSourcesSection
                    activitySection
                }
                recentTranscriptsSection
            }
            .padding(Spacing.xxxl)
        }
        .navigationTitle("Dashboard")
    }

    // MARK: - Stats Row

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Stats")
                .sectionHeaderStyle()

            HStack(spacing: Spacing.lg) {
                StatCell(label: "Total words", value: formattedCount(totalWords))
                StatCell(label: "Time saved", value: formattedDuration(totalDuration))
                StatCell(label: "Average WPM", value: String(format: "%.0f", averageWPM))
            }
        }
    }

    // MARK: - Top Sources

    private var topSourcesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Top sources")
                .sectionHeaderStyle()

            if topSources.isEmpty {
                Text("No data yet")
                    .font(OType.body)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topSources.enumerated()), id: \.offset) { index, source in
                        if index > 0 {
                            SubtleDivider(leadingInset: 42)
                        }
                        HStack(spacing: Spacing.sm) {
                            appIcon(for: source.bundleID)
                            Text(source.name)
                                .font(OType.body)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("\(formattedCount(source.wordCount)) words")
                                .font(OType.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                    }
                }
                .cardStyle(padding: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Activity Grid

    private var activitySection: some View {
        let grid = activityData
        let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Monthly activity")
                .sectionHeaderStyle()

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                HStack(alignment: .top, spacing: Spacing.xxs) {
                    VStack(spacing: Spacing.xxs) {
                        ForEach(0..<7, id: \.self) { row in
                            Text(weekdays[row])
                                .font(OType.micro)
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 14, height: 14)
                        }
                    }

                    let weeks = stride(from: 0, to: grid.days.count, by: 7).map {
                        Array(grid.days[$0..<min($0 + 7, grid.days.count)])
                    }
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: Spacing.xxs) {
                            ForEach(week, id: \.date) { day in
                                activityCell(day: day, maxCount: grid.maxCount)
                            }
                        }
                    }
                }

                Text("\(grid.activeDays) active days")
                    .font(OType.micro)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.top, Spacing.xxs)
            }
            .cardStyle()
        }
    }

    private func activityCell(day: ActivityDay, maxCount: Int) -> some View {
        let intensity: Double
        if day.isFuture {
            intensity = -1
        } else if day.wordCount == 0 {
            intensity = 0
        } else if maxCount > 0 {
            intensity = max(0.2, Double(day.wordCount) / Double(maxCount))
        } else {
            intensity = 0
        }

        return RoundedRectangle(cornerRadius: Radius.xs)
            .fill(intensity < 0 ? Color.clear : (intensity == 0 ? Color.surfaceSecondary : Color.brand.opacity(intensity)))
            .frame(width: 14, height: 14)
    }

    // MARK: - Recent Transcripts

    private var recentTranscriptsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Recent transcripts")
                .sectionHeaderStyle()

            if entries.isEmpty {
                Text("No transcripts yet")
                    .font(OType.body)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            SubtleDivider(leadingInset: 56)
                        }
                        HStack(spacing: Spacing.md) {
                            Text(entry.timestamp, format: .dateTime.hour().minute())
                                .font(OType.caption)
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 40, alignment: .trailing)

                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                if let appName = entry.targetAppName {
                                    HStack(spacing: Spacing.xs) {
                                        appIcon(for: entry.targetAppBundleID)
                                        Text(appName)
                                            .font(OType.captionMedium)
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                }
                                Text(entry.text)
                                    .font(OType.body)
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Text("\(entry.wordCount) words")
                                .font(OType.micro)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func appIcon(for bundleID: String?) -> some View {
        if let bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path()))
                .resizable()
                .frame(width: 16, height: 16)
        }
    }

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

// MARK: - Supporting Types

private struct ActivityDay {
    let date: Date
    let wordCount: Int
    let isFuture: Bool
}

private struct ActivityGrid {
    let days: [ActivityDay]
    let maxCount: Int
    let activeDays: Int
}

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(OType.caption)
                .foregroundStyle(Color.textTertiary)
            Text(value)
                .font(OType.stat)
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
