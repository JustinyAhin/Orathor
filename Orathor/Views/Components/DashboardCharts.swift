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

    @State private var hoveredDate: Date?

    private var latest: DayPoint? { points.last }
    private var hoveredPoint: DayPoint? {
        hoveredDate.flatMap { nearestPoint(to: $0, in: points) }
    }

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
        Chart {
            ForEach(points) { point in
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
            }

            if let hoveredPoint {
                RuleMark(x: .value("Day", hoveredPoint.date))
                    .foregroundStyle(Color.borderDefault)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(
                        position: .top,
                        spacing: 6,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ChartTooltip(
                            title: hoveredPoint.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                            value: "\(Int(hoveredPoint.value)) wpm",
                            color: .indicatorBlue
                        )
                    }
                PointMark(
                    x: .value("Day", hoveredPoint.date),
                    y: .value("WPM", hoveredPoint.value)
                )
                .foregroundStyle(Color.indicatorBlue)
                .symbolSize(60)
            } else if let latest {
                PointMark(
                    x: .value("Day", latest.date),
                    y: .value("WPM", latest.value)
                )
                .foregroundStyle(Color.indicatorBlue)
                .symbolSize(50)
                .annotation(position: .top, spacing: 4) {
                    Text("\(Int(latest.value))")
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
        .chartOverlay { proxy in
            dateHoverOverlay(proxy, points: points, into: $hoveredDate)
        }
        .animation(.easeOut(duration: 0.12), value: hoveredDate)
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

    @State private var hoveredDate: Date?

    private var maxValue: Double { max(points.map(\.value).max() ?? 1, 1) }
    private var hoveredPoint: DayPoint? {
        hoveredDate.flatMap { nearestPoint(to: $0, in: points) }
    }

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
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Words", point.value)
                )
                .cornerRadius(3)
                .foregroundStyle(barColor(for: point))
            }

            if let hoveredPoint {
                RuleMark(x: .value("Day", hoveredPoint.date, unit: .day))
                    .foregroundStyle(Color.borderDefault)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(
                        position: .top,
                        spacing: 6,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ChartTooltip(
                            title: hoveredPoint.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                            value: "\(Int(hoveredPoint.value)) words",
                            color: .indicatorBlue
                        )
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
        .chartOverlay { proxy in
            dateHoverOverlay(proxy, points: points, into: $hoveredDate)
        }
        .animation(.easeOut(duration: 0.12), value: hoveredDate)
        .frame(height: 130)
    }

    private func barColor(for point: DayPoint) -> Color {
        if let hoveredPoint {
            return point.id == hoveredPoint.id ? Color.indicatorBlue : Color.indicatorBlue.opacity(0.3)
        }
        return point.value >= maxValue ? Color.indicatorBlue : Color.indicatorBlue.opacity(0.5)
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

    @State private var hoveredEngine: SpeechEngine?

    private var total: Int { slices.reduce(0) { $0 + $1.count } }

    private var dominant: EngineSlice? {
        slices.max(by: { $0.count < $1.count })
    }

    private var dominantPercent: Int {
        guard total > 0, let dominant else { return 0 }
        return percent(dominant.count)
    }

    private var hoveredSlice: EngineSlice? {
        hoveredEngine.flatMap { engine in slices.first { $0.engine == engine } }
    }

    private func percent(_ count: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(count) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            chart
                .frame(height: 130)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(slices) { slice in
                    let isHovered = slice.engine == hoveredEngine
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(slice.color)
                            .frame(width: 6, height: 6)
                        Text(slice.shortName)
                            .font(OType.caption)
                            .foregroundStyle(isHovered ? Color.textPrimary : Color.textSecondary)
                        Spacer()
                        Text("\(slice.count)")
                            .font(OType.monoSmall)
                            .foregroundStyle(isHovered ? Color.textSecondary : Color.textTertiary)
                    }
                    .opacity(hoveredEngine == nil || isHovered ? 1 : 0.5)
                }
            }
            .animation(.easeOut(duration: 0.12), value: hoveredEngine)
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
            .opacity(hoveredEngine == nil || hoveredEngine == slice.engine ? 1 : 0.35)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            centerLabel
        }
        .chartOverlay { _ in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        let next: SpeechEngine?
                        switch phase {
                        case .active(let location):
                            next = engine(at: location, in: geo.size)
                        case .ended:
                            next = nil
                        }
                        if next != hoveredEngine {
                            hoveredEngine = next
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.12), value: hoveredEngine)
    }

    @ViewBuilder
    private var centerLabel: some View {
        if let hoveredSlice {
            VStack(spacing: 0) {
                Text("\(percent(hoveredSlice.count))%")
                    .font(OType.statUnit)
                    .foregroundStyle(Color.textPrimary)
                Text(hoveredSlice.shortName)
                    .font(OType.monoMicro)
                    .foregroundStyle(Color.textTertiary)
            }
        } else {
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

    private func engine(at location: CGPoint, in size: CGSize) -> SpeechEngine? {
        guard total > 0 else { return nil }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radius = (dx * dx + dy * dy).squareRoot()
        let outer = min(size.width, size.height) / 2
        let inner = outer * 0.64
        guard radius >= inner, radius <= outer else { return nil }

        // Angle measured clockwise from 12 o'clock, matching SectorMark layout.
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let target = angle / (2 * .pi) * Double(total)

        var cumulative = 0.0
        for slice in slices {
            cumulative += Double(slice.count)
            if target <= cumulative { return slice.engine }
        }
        return slices.last?.engine
    }
}

// MARK: - Hover Tooltip

struct ChartTooltip: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            Text(title)
                .font(OType.monoMicro)
                .foregroundStyle(Color.textTertiary)
            HStack(spacing: Spacing.xxs) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                Text(value)
                    .font(OType.monoSmall)
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
        .fixedSize()
    }
}

// MARK: - Hover Helpers

func nearestPoint(to date: Date, in points: [DayPoint]) -> DayPoint? {
    points.min(by: {
        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
    })
}

@ViewBuilder
func dateHoverOverlay(_ proxy: ChartProxy, points: [DayPoint], into binding: Binding<Date?>) -> some View {
    GeometryReader { geo in
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    guard let plotFrame = proxy.plotFrame else { return }
                    let x = location.x - geo[plotFrame].origin.x
                    guard let date: Date = proxy.value(atX: x),
                          let snapped = nearestPoint(to: date, in: points)?.date
                    else { return }
                    if binding.wrappedValue != snapped {
                        binding.wrappedValue = snapped
                    }
                case .ended:
                    binding.wrappedValue = nil
                }
            }
    }
}

// MARK: - Period Picker

struct PeriodPicker: View {
    @Binding var selection: ActivityPeriod

    var body: some View {
        SegmentedControl(options: ActivityPeriod.allCases, selection: $selection) { $0.label }
    }
}
