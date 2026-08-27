import SwiftUI

struct DashboardView: View {
    let historyService: TranscriptHistoryService

    @AppStorage("dashboardActivityPeriod", store: AppPreferences.shared)
    private var period: ActivityPeriod = .week
    @State private var playbackService = AudioPlaybackService()

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
                    header
                    statsStrip
                    trendsSection
                    topAppsSection
                    recentSection
                }
                .padding(Spacing.xxxl)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("\(greeting), \(firstName)")
                .font(OType.greeting)
                .foregroundStyle(Color.textPrimary)
            summaryLine
                .font(OType.summary)
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    private var firstName: String {
        NSFullUserName().split(separator: " ").first.map(String.init) ?? "there"
    }

    private var summaryLine: Text {
        let words = colored(formattedCount(totalWords), .indicatorBlue)
        let sessions = colored("\(entries.count)", .indicatorGreen)
        let saved = colored(formattedDuration(timeSaved), .brand)
        let wpm = colored(String(format: "%.0f", averageWPM), .indicatorGreen)

        var line = Text("You've dictated ") + words + Text(" words across ")
            + sessions + Text(entries.count == 1 ? " session" : " sessions")
            + Text(", saving about ") + saved + Text(" — averaging ")
            + wpm + Text(" wpm.")

        if currentStreak > 0 {
            let streak = colored("\(currentStreak)-day", .brand)
            line = line + Text("  You're on a ") + streak + Text(" streak.")
        }
        return line
    }

    private func colored(_ value: String, _ color: Color) -> Text {
        Text(value).foregroundColor(color).fontWeight(.medium)
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
        HStack(spacing: Spacing.md) {
            StatCard(value: formattedCount(totalWords), label: "Words", color: .indicatorBlue)
            StatCard(value: "\(entries.count)", label: "Sessions", color: .indicatorGreen)
            StatCard(value: formattedDuration(timeSaved), label: "Time saved", color: .brand)
            StatCard(value: String(format: "%.0f", averageWPM), unit: "wpm", label: "Avg speed", color: .indicatorYellow)
        }
    }

    // MARK: - Day Summaries (shared by streak, activity, WPM derivations)

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

    private var currentStreak: Int { historyService.currentStreak }

    private var wordsPerDay: [DayPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let summaries = daySummaries
        return (0..<period.days).reversed().compactMap { offset -> DayPoint? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayPoint(date: day, value: Double(summaries[day]?.wordCount ?? 0))
        }
    }

    private var wpmPerDay: [DayPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let summaries = daySummaries
        return (0..<period.days).reversed().compactMap { offset -> DayPoint? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let summary = summaries[day], summary.durationSeconds > 0 else { return nil }
            let wpm = Double(summary.wordCount) / (summary.durationSeconds / 60)
            return DayPoint(date: day, value: wpm)
        }
    }

    private var wpmDeltaPercent: Double? {
        let points = wpmPerDay
        guard points.count >= 2 else { return nil }
        let mid = points.count / 2
        let older = points[..<mid]
        let recent = points[mid...]
        guard !older.isEmpty, !recent.isEmpty else { return nil }
        let olderMean = older.map(\.value).reduce(0, +) / Double(older.count)
        let recentMean = recent.map(\.value).reduce(0, +) / Double(recent.count)
        guard olderMean > 0 else { return nil }
        return (recentMean - olderMean) / olderMean * 100
    }

    // MARK: - Engines

    private var engineSlices: [EngineSlice] {
        let colors: [SpeechEngine: Color] = [
            .deepgram: .indicatorBlue,
            .apple: .indicatorGreen,
            .openAIWhisper: .indicatorOrange
        ]
        var counts: [SpeechEngine: Int] = [:]
        for entry in entries {
            guard let engine = entry.engine else { continue }
            counts[engine, default: 0] += 1
        }
        return counts
            .map { EngineSlice(engine: $0.key, count: $0.value, color: colors[$0.key] ?? .indicatorGray) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Trends (period-scoped)

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Spacer()
                PeriodPicker(selection: $period)
            }
            WPMTrendChart(points: wpmPerDay, deltaPercent: wpmDeltaPercent)
            activityRow
        }
    }

    @ViewBuilder
    private var activityRow: some View {
        let slices = engineSlices
        if slices.isEmpty {
            activityCard
        } else {
            HStack(alignment: .top, spacing: Spacing.md) {
                activityCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                enginesCard(slices)
                    .frame(width: 200)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ContentSectionHeader(title: "Activity", symbol: "chart.bar.fill")
            ActivityBarChart(points: wordsPerDay)
                .frame(maxHeight: .infinity)
        }
        .statCardStyle()
    }

    private func enginesCard(_ slices: [EngineSlice]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ContentSectionHeader(title: "Engines", symbol: "waveform")
            EngineDonut(slices: slices)
        }
        .statCardStyle()
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
                ContentSectionHeader(title: "Top apps", symbol: "macwindow")

                VStack(spacing: 0) {
                    ForEach(Array(apps.prefix(5).enumerated()), id: \.element.bundleID) { index, app in
                        if index > 0 {
                            SubtleDivider(leadingInset: Spacing.lg)
                        }
                        TopAppRow(name: app.name, bundleID: app.bundleID, count: app.count, maxCount: apps.first?.count ?? 1)
                    }
                }
                .statCardStyle(padding: 0)
            }
        }
    }

    // MARK: - Recent Transcripts

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ContentSectionHeader(title: "Recent", symbol: "clock")

            VStack(spacing: Spacing.xxxs) {
                ForEach(entries.prefix(5)) { entry in
                    TranscriptRow(
                        entry: entry,
                        historyService: historyService,
                        playbackService: playbackService
                    )
                }
            }
            .padding(Spacing.xs)
            .statCardStyle(padding: 0)
        }
    }

    // MARK: - Helpers

    private func formattedCount(_ count: Int) -> String {
        count.abbreviated
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

// MARK: - Day Summary

struct DaySummary {
    var dictationCount: Int = 0
    var wordCount: Int = 0
    var durationSeconds: Double = 0
}

// MARK: - Top App Row

private struct TopAppRow: View {
    let name: String
    let bundleID: String
    let count: Int
    let maxCount: Int

    private var barFraction: CGFloat {
        CGFloat(count) / CGFloat(max(maxCount, 1))
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            appIcon

            Text(name)
                .font(OType.body)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.borderSubtle.opacity(0.5))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.indicatorBlue)
                        .frame(width: max(6, geo.size.width * barFraction), height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }

            Text("\(count)")
                .font(OType.monoSmall)
                .foregroundStyle(Color.textSecondary)
                .frame(minWidth: 28, alignment: .trailing)
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
