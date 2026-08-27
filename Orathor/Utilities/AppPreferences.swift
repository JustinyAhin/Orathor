import Foundation

enum AppPreferences {
    /// Keep app preferences in the production domain so Debug and customer
    /// builds share settings even though they use different bundle identifiers.
    static let shared = UserDefaults(suiteName: "segbedji.Orathor") ?? .standard
}
