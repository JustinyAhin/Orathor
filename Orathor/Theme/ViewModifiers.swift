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
    }
}

extension View {
    func cardStyle(radius: CGFloat = Radius.xl, padding: CGFloat = Spacing.lg) -> some View {
        modifier(CardModifier(radius: radius, padding: padding))
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
