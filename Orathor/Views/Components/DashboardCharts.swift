import Charts
import SwiftUI

// MARK: - Shared Types

struct DayPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

enum ActivityPeriod: Int, CaseIterable, Identifiable {
    case week = 7
    case fortnight = 14
    case month = 30

    var id: Int { rawValue }
    var label: String { "\(rawValue)d" }
    var days: Int { rawValue }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    var unit: String? = nil
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(OType.statNumber)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(OType.statNumberUnit)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(OType.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .statCardStyle()
    }
}

// MARK: - WPM Trend Chart

struct WPMTrendChart: View {
    let points: [DayPoint]
    let deltaPercent: Double?

    private var latest: DayPoint? { points.last }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ContentSectionHeader(title: "Words per minute", symbol: "gauge.with.dots.needle.67percent") {
                if let deltaPercent, abs(deltaPercent) >= 1 {
                    deltaBadge(deltaPercent)
                }
            }

            if points.count < 2 {
                placeholder
            } else {
                chart
            }
        }
        .statCardStyle()
    }

    private var chart: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Day", point.date),
                y: .value("WPM", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.indicatorBlue.opacity(0.22), Color.indicatorBlue.opacity(0.01)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Day", point.date),
                y: .value("WPM", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.indicatorBlue)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))

            if let latest, point.id == latest.id {
                PointMark(
                    x: .value("Day", point.date),
                    y: .value("WPM", point.value)
                )
                .foregroundStyle(Color.indicatorBlue)
                .symbolSize(50)
                .annotation(position: .top, spacing: 4) {
                    Text("\(Int(point.value))")
                        .font(OType.monoSmall)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(OType.monoMicro)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(height: 150)
    }

    private var placeholder: some View {
        Text("Not enough data yet")
            .font(OType.caption)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
    }

    private func deltaBadge(_ percent: Double) -> some View {
        let isUp = percent >= 0
        let color: Color = isUp ? .indicatorGreen : .indicatorGray
        return HStack(spacing: 3) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text("\(abs(Int(percent.rounded())))% \(isUp ? "faster" : "slower")")
                .font(OType.monoSmall)
        }
        .foregroundStyle(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Activity Bar Chart

struct ActivityBarChart: View {
    let points: [DayPoint]

    private var maxValue: Double { max(points.map(\.value).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if points.allSatisfy({ $0.value == 0 }) {
                placeholder
            } else {
                chart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chart: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Words", point.value)
            )
            .cornerRadius(3)
            .foregroundStyle(point.value >= maxValue ? Color.indicatorBlue : Color.indicatorBlue.opacity(0.5))
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(OType.monoMicro)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(height: 130)
    }

    private var placeholder: some View {
        Text("No activity in this period")
            .font(OType.caption)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .center)
    }
}

// MARK: - Engine Donut

struct EngineSlice: Identifiable {
    let engine: SpeechEngine
    let count: Int
    let color: Color
    var id: String { engine.rawValue }

    var shortName: String {
        switch engine {
        case .apple: "Apple"
        case .deepgram: "Deepgram"
        case .openAIWhisper: "Whisper"
        }
    }
}

struct EngineDonut: View {
    let slices: [EngineSlice]

    private var total: Int { slices.reduce(0) { $0 + $1.count } }

    private var dominantPercent: Int {
        guard total > 0, let top = slices.max(by: { $0.count < $1.count }) else { return 0 }
        return Int((Double(top.count) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            chart
                .frame(height: 130)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(slices) { slice in
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(slice.color)
                            .frame(width: 6, height: 6)
                        Text(slice.shortName)
                            .font(OType.caption)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text("\(slice.count)")
                            .font(OType.monoSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chart: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Count", slice.count),
                innerRadius: .ratio(0.64),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(slice.color)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            VStack(spacing: 0) {
                Text("\(dominantPercent)%")
                    .font(OType.statUnit)
                    .foregroundStyle(Color.textPrimary)
                Text("top")
                    .font(OType.monoMicro)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }
}

// MARK: - Period Picker

struct PeriodPicker: View {
    @Binding var selection: ActivityPeriod

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ActivityPeriod.allCases) { period in
                let isSelected = period == selection
                Button {
                    selection = period
                } label: {
                    Text(period.label)
                        .font(OType.monoSmall)
                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(isSelected ? Color.borderSubtle : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.surfaceSecondary)
        )
    }
}
