import SwiftUI

// MARK: - Color Tokens
// Most colors auto-generated from asset catalog (SurfacePrimary, BorderSubtle, etc.)

extension Color {
    static let brand = Color.accentColor
}

// MARK: - Brand Gradient

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [.brand, .brandGradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Spacing Scale

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let xxxxl: CGFloat = 48
}

// MARK: - Corner Radius

enum Radius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
    static let xl: CGFloat = 12
}

// MARK: - Typography

enum OType {
    static let largeTitle = Font.system(size: 24, weight: .semibold)
    static let title = Font.system(size: 17, weight: .semibold)
    static let headline = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let callout = Font.system(size: 12, weight: .regular)
    static let caption = Font.system(size: 11, weight: .regular)
    static let captionMedium = Font.system(size: 11, weight: .medium)
    static let micro = Font.system(size: 10, weight: .medium)

    // Monospace — distinctive technical precision for data
    static let stat = Font.system(size: 32, weight: .bold, design: .monospaced)
    static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let monoMicro = Font.system(size: 10, weight: .medium, design: .monospaced)
}
