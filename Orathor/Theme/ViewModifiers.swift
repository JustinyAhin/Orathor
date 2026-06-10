import SwiftUI

// MARK: - Card Style

struct CardModifier: ViewModifier {
    var radius: CGFloat = Radius.xl
    var padding: CGFloat = Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

extension View {
    func cardStyle(radius: CGFloat = Radius.xl, padding: CGFloat = Spacing.lg) -> some View {
        modifier(CardModifier(radius: radius, padding: padding))
    }
}

// MARK: - Gradient Accent Card (top border accent)

struct GradientAccentCardModifier: ViewModifier {
    var radius: CGFloat = Radius.xl
    var padding: CGFloat = Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
            .overlay(alignment: .top) {
                Color.brand
                    .frame(height: 2)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: radius,
                            topTrailingRadius: radius
                        )
                    )
            }
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

extension View {
    func gradientAccentCard(radius: CGFloat = Radius.xl, padding: CGFloat = Spacing.lg) -> some View {
        modifier(GradientAccentCardModifier(radius: radius, padding: padding))
    }
}

// MARK: - Left Accent Card (left border accent)

struct LeftAccentCardModifier: ViewModifier {
    var radius: CGFloat = Radius.xl
    var padding: CGFloat = Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
            .overlay(alignment: .leading) {
                Color.brand
                    .frame(width: 2.5)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: radius,
                        bottomLeadingRadius: radius
                    )
                )
            }
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

extension View {
    func leftAccentCard(radius: CGFloat = Radius.xl, padding: CGFloat = Spacing.lg) -> some View {
        modifier(LeftAccentCardModifier(radius: radius, padding: padding))
    }
}

// MARK: - Stat / Chart Card Style
// Chunkier card for dashboard stat + chart surfaces — larger radius, generous padding.

struct StatCardModifier: ViewModifier {
    var padding: CGFloat = Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
    }
}

extension View {
    func statCardStyle(padding: CGFloat = Spacing.lg) -> some View {
        modifier(StatCardModifier(padding: padding))
    }
}

// MARK: - Tinted Icon Tile
// Rounded square with a tinted background and a full-color SF Symbol — used on stat cards.

struct TintedIconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 28
    var symbolSize: CGFloat = 13

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(color.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(color)
            )
    }
}

// MARK: - Content Section Header

struct ContentSectionHeader<Trailing: View>: View {
    let title: String
    let symbol: String
    var color: Color = .indicatorBlue
    var meta: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(OType.contentHeader)
                .foregroundStyle(Color.textPrimary)
            if let meta {
                Text(meta)
                    .font(OType.monoSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer(minLength: Spacing.sm)
            trailing
        }
    }
}

extension ContentSectionHeader where Trailing == EmptyView {
    init(title: String, symbol: String, color: Color = .indicatorBlue, meta: String? = nil) {
        self.init(title: title, symbol: symbol, color: color, meta: meta) { EmptyView() }
    }
}

// MARK: - Section Header

struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(OType.captionMedium)
            .foregroundStyle(Color.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

extension View {
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderModifier())
    }
}

// MARK: - Button Styles

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OType.caption)
            .foregroundStyle(configuration.isPressed ? Color.textPrimary : Color.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(configuration.isPressed ? Color.borderSubtle : Color.clear)
            )
    }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .foregroundStyle(configuration.isPressed ? Color.textPrimary : Color.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(configuration.isPressed ? Color.borderSubtle : Color.clear)
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Subtle Divider

struct SubtleDivider: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}
