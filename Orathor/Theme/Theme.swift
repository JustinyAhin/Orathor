import SwiftUI

// MARK: - Color Tokens
// Most colors auto-generated from asset catalog (SurfacePrimary, BorderSubtle, etc.)

extension Color {
    static let brand = Color.accentColor

    // Multi-color indicator palette (Readout-style)
    static let indicatorBlue = Color(red: 0.231, green: 0.510, blue: 0.965)    // #3B82F6
    static let indicatorGreen = Color(red: 0.133, green: 0.773, blue: 0.369)   // #22C55E
    static let indicatorOrange = Color(red: 0.961, green: 0.620, blue: 0.043)  // #F59E0B
    static let indicatorRed = Color(red: 0.937, green: 0.267, blue: 0.267)     // #EF4444
    static let indicatorYellow = Color(red: 0.918, green: 0.702, blue: 0.031)  // #EAB308
    static let indicatorGray = Color(red: 0.420, green: 0.447, blue: 0.502)    // #6B7280
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
