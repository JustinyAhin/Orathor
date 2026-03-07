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

    private var timeSaved: TimeInterval {
        let estimatedTypingSeconds = Double(totalWords) / 60.0 * 60.0
        return max(0, estimatedTypingSeconds - totalDuration)
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
                    activitySection
                    topAppsSection
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
            HomeStatItem(value: formattedDuration(timeSaved), label: "saved")
            HomeStatItem(value: String(format: "%.0f", averageWPM), label: "avg wpm")
        }
        .gradientAccentCard()
    }

    // MARK: - Activity Streak

    private var daySummaries: [Date: DaySummary] {
        var map: [Date: DaySummary] = [:]
        let calendar = Calendar.current
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            var summary = map[day] ?? DaySummary()
            summary.dictationCount += 1
            summary.wordCount += entry.wordCount
            summary.durationSeconds += entry.durationSeconds
            map[day] = summary
        }
        return map
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var day = today

        // If no activity today, start checking from yesterday
        if daySummaries[today] == nil {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            day = yesterday
        }

        while daySummaries[day] != nil {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .lastTextBaseline) {
                Text("Activity")
                    .sectionHeaderStyle()
                Spacer()
                if currentStreak > 0 {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.brand)
                        Text("\(currentStreak) day streak")
                            .font(OType.monoSmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            ActivityGrid(daySummaries: daySummaries)
                .cardStyle(padding: Spacing.md)
        }
    }

    // MARK: - Top Apps

    private var topApps: [(name: String, bundleID: String, count: Int)] {
        var counts: [String: (name: String, bundleID: String, count: Int)] = [:]
        for entry in entries {
            guard let name = entry.targetAppName, let bundleID = entry.targetAppBundleID else { continue }
            if let existing = counts[bundleID] {
                counts[bundleID] = (name: existing.name, bundleID: bundleID, count: existing.count + 1)
            } else {
                counts[bundleID] = (name: name, bundleID: bundleID, count: 1)
            }
        }
        return counts.values.sorted { $0.count > $1.count }
    }

    @ViewBuilder
    private var topAppsSection: some View {
        let apps = topApps
        if !apps.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Top Apps")
                    .sectionHeaderStyle()

                VStack(spacing: 0) {
                    ForEach(Array(apps.prefix(5).enumerated()), id: \.element.bundleID) { index, app in
                        if index > 0 {
                            SubtleDivider(leadingInset: Spacing.lg)
                        }
                        TopAppRow(rank: index + 1, name: app.name, bundleID: app.bundleID, count: app.count, maxCount: apps.first?.count ?? 1)
                    }
                }
                .leftAccentCard(padding: 0)
            }
        }
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

// MARK: - Day Summary

private struct DaySummary {
    var dictationCount: Int = 0
    var wordCount: Int = 0
    var durationSeconds: Double = 0
}

// MARK: - Activity Grid

private struct ActivityGrid: View {
    let daySummaries: [Date: DaySummary]

    @State private var hoveredDate: Date?

    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2.5

    private var maxCount: Int {
        daySummaries.values.map(\.dictationCount).max() ?? 1
    }

    /// Builds a proper weekday-aligned grid like GitHub's contribution graph.
    /// Each column is a calendar week (Mon–Sun). Last column contains today.
    /// First column may be partial (starts mid-week).
    private func weeksGrid(columnCount: Int) -> [[Date?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let todayWeekday = calendar.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon, ... 7=Sat → offset to make Monday = row 0
        let daysSinceMonday = (todayWeekday + 5) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else {
            return []
        }

        guard let gridStart = calendar.date(byAdding: .weekOfYear, value: -(columnCount - 1), to: thisMonday) else {
            return []
        }

        var grid: [[Date?]] = []
        for col in 0..<columnCount {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: col, to: gridStart) else { continue }
            var week: [Date?] = []
            for row in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: row, to: weekStart) else {
                    week.append(nil)
                    continue
                }
                if date > today {
                    week.append(nil)
                } else {
                    week.append(date)
                }
            }
            grid.append(week)
        }
        return grid
    }

    private func intensity(for date: Date) -> Double {
        guard let summary = daySummaries[date], summary.dictationCount > 0 else { return 0 }
        if maxCount <= 1 { return 1.0 }
        let normalized = Double(summary.dictationCount) / Double(maxCount)
        if normalized <= 0.25 { return 0.3 }
        if normalized <= 0.5 { return 0.55 }
        if normalized <= 0.75 { return 0.8 }
        return 1.0
    }

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let columnCount = max(4, Int(availableWidth / (cellSize + cellSpacing)))
            let grid = weeksGrid(columnCount: columnCount)

            VStack(alignment: .trailing, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: cellSpacing) {
                    // Weekday labels
                    VStack(alignment: .trailing, spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { row in
                            if row == 0 || row == 2 || row == 4 {
                                Text(weekdayLabel(row))
                                    .font(OType.monoMicro)
                                    .foregroundStyle(Color.textTertiary)
                                    .frame(height: cellSize)
                            } else {
                                Color.clear.frame(width: 1, height: cellSize)
                            }
                        }
                    }

                    ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { row in
                                if let date = week[row] {
                                    ActivityCell(
                                        date: date,
                                        level: intensity(for: date),
                                        summary: daySummaries[date],
                                        cellSize: cellSize,
                                        hoveredDate: $hoveredDate
                                    )
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }

                // Legend
                HStack(spacing: Spacing.xs) {
                    Text("Less")
                        .font(OType.monoMicro)
                        .foregroundStyle(Color.textTertiary)
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.borderSubtle.opacity(0.4))
                            .frame(width: 8, height: 8)
                        ForEach([0.3, 0.55, 0.8, 1.0], id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.brand.opacity(level))
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text("More")
                        .font(OType.monoMicro)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .frame(height: 7 * cellSize + 6 * cellSpacing + Spacing.sm + 12)
    }

    private func weekdayLabel(_ row: Int) -> String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][row]
    }
}

// MARK: - Activity Cell

private struct ActivityCell: View {
    let date: Date
    let level: Double
    let summary: DaySummary?
    let cellSize: CGFloat
    @Binding var hoveredDate: Date?

    private var isHovered: Bool { hoveredDate == date }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(level > 0 ? Color.brand.opacity(level) : Color.borderSubtle.opacity(0.4))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.textPrimary.opacity(isHovered ? 0.6 : 0), lineWidth: 1)
            )
            .onHover { hovered in
                hoveredDate = hovered ? date : nil
            }
            .popover(
                isPresented: .init(
                    get: { isHovered },
                    set: { if !$0 { hoveredDate = nil } }
                ),
                arrowEdge: .top
            ) {
                CellPopoverContent(date: date, summary: summary)
            }
    }
}

// MARK: - Cell Popover Content

private struct CellPopoverContent: View {
    let date: Date
    let summary: DaySummary?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(OType.captionMedium)
                .foregroundStyle(Color.textPrimary)

            if let summary, summary.dictationCount > 0 {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    DetailChip(icon: "mic.fill", text: "\(summary.dictationCount) dictation\(summary.dictationCount == 1 ? "" : "s")")
                    DetailChip(icon: "text.word.spacing", text: "\(summary.wordCount) words")
                    DetailChip(icon: "clock", text: formatDuration(summary.durationSeconds))
                }
            } else {
                Text("No dictations")
                    .font(OType.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(Spacing.sm)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}

private struct DetailChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.xxxs) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(Color.brand)
            Text(text)
                .font(OType.monoMicro)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxxs)
        .background(Color.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.xs))
    }
}

// MARK: - Top App Row

private struct TopAppRow: View {
    let rank: Int
    let name: String
    let bundleID: String
    let count: Int
    let maxCount: Int

    private var barFraction: CGFloat {
        CGFloat(count) / CGFloat(max(maxCount, 1))
    }

    private var barOpacity: Double {
        // Gradient from 1.0 (rank 1) down to 0.35 (rank 5)
        max(0.35, 1.0 - Double(rank - 1) * 0.15)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            appIcon

            Text(name)
                .font(OType.body)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .frame(minWidth: 60, alignment: .leading)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brand.opacity(barOpacity))
                    .frame(width: max(4, geo.size.width * barFraction), height: 6)
                    .frame(maxHeight: .infinity, alignment: .center)
            }

            Text("\(count)")
                .font(OType.monoSmall)
                .foregroundStyle(Color.textSecondary)
                .frame(minWidth: 20, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path()))
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 20, height: 20)
        }
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
