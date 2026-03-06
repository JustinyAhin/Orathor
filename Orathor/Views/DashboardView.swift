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

    // Activity grid: last 4 weeks of daily word counts
    private var activityData: ActivityGrid {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build a map of date -> word count
        var dailyCounts: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            dailyCounts[day, default: 0] += entry.wordCount
        }

        // Generate last 4 weeks (28 days), starting from Monday
        let todayWeekday = calendar.component(.weekday, from: today) // 1=Sun ... 7=Sat
        // Days since last Monday (weekday 2)
        let daysSinceMonday = (todayWeekday + 5) % 7 // 0=Mon, 1=Tue, ...
        let weeksToShow = 4
        let totalDays = weeksToShow * 7
        let gridStart = calendar.date(byAdding: .day, value: -(totalDays - 1 - (6 - daysSinceMonday)), to: today)!

        var days: [ActivityDay] = []
        for i in 0..<totalDays {
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
            VStack(alignment: .leading, spacing: 24) {
                statsSection
                HStack(alignment: .top, spacing: 24) {
                    topSourcesSection
                    activitySection
                }
                recentTranscriptsSection
            }
            .padding(32)
        }
        .navigationTitle("Dashboard")
    }

    // MARK: - Stats Row

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your stats")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 0) {
                StatCell(label: "Total words", value: formattedCount(totalWords))
                Divider().frame(height: 50)
                StatCell(label: "Time saved", value: formattedDuration(totalDuration))
                Divider().frame(height: 50)
                StatCell(label: "Average WPM", value: String(format: "%.0f", averageWPM))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Top Sources

    private var topSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top sources")
                .font(.title3)
                .fontWeight(.semibold)

            if topSources.isEmpty {
                Text("No data yet")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topSources.enumerated()), id: \.offset) { index, source in
                        if index > 0 {
                            Divider().padding(.horizontal, 16)
                        }
                        HStack(spacing: 10) {
                            appIcon(for: source.bundleID)
                            Text(source.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(formattedCount(source.wordCount)) words")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Activity Grid

    private var activitySection: some View {
        let grid = activityData
        let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

        return VStack(alignment: .leading, spacing: 12) {
            Text("Monthly activity")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .trailing, spacing: 4) {
                // Day labels + grid
                HStack(alignment: .top, spacing: 4) {
                    // Weekday labels
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { row in
                            Text(weekdays[row])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 14, height: 14)
                        }
                    }

                    // Weeks as columns
                    let weeks = stride(from: 0, to: grid.days.count, by: 7).map {
                        Array(grid.days[$0..<min($0 + 7, grid.days.count)])
                    }
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 4) {
                            ForEach(week, id: \.date) { day in
                                activityCell(day: day, maxCount: grid.maxCount)
                            }
                        }
                    }
                }

                HStack(spacing: 4) {
                    Text("\(grid.activeDays) active days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func activityCell(day: ActivityDay, maxCount: Int) -> some View {
        let intensity: Double
        if day.isFuture {
            intensity = -1 // will render as empty/invisible
        } else if day.wordCount == 0 {
            intensity = 0
        } else if maxCount > 0 {
            intensity = max(0.2, Double(day.wordCount) / Double(maxCount))
        } else {
            intensity = 0
        }

        return RoundedRectangle(cornerRadius: 3)
            .fill(intensity < 0 ? Color.clear : (intensity == 0 ? Color.primary.opacity(0.08) : Color.accentColor.opacity(intensity)))
            .frame(width: 14, height: 14)
    }

    // MARK: - Recent Transcripts

    private var recentTranscriptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent transcripts")
                .font(.title3)
                .fontWeight(.semibold)

            if entries.isEmpty {
                Text("No transcripts yet")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().padding(.horizontal, 16)
                        }
                        HStack(spacing: 12) {
                            Text(entry.timestamp, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(width: 40, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 4) {
                                if let appName = entry.targetAppName {
                                    HStack(spacing: 6) {
                                        appIcon(for: entry.targetAppBundleID)
                                        Text(appName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(entry.text)
                                    .font(.subheadline)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Text("\(entry.wordCount) words")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
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
        VStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}
