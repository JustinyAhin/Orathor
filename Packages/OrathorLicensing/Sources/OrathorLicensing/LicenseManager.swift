// Open-source stub of the Orathor licensing module.
//
// Source builds compile this module and are always licensed — no trial,
// no key entry, no network calls. Official binaries distributed by the
// maintainer replace this package's contents at release time with a
// closed implementation that enforces a trial and Polar.sh license keys.
// The public API below is the contract both implementations share.

import Foundation

public enum LicenseState: Equatable, Sendable {
    case licensed(email: String?)
    case trialing(daysLeft: Int)
    case trialExpired
    case licenseInvalid(reason: String)
}

public enum LicenseError: LocalizedError, Equatable {
    case invalidKey
    case activationLimitReached
    case network(String)
    case storage(String)
    case notActivated

    public var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "This license key is not valid."
        case .activationLimitReached:
            return "This license key has reached its activation limit."
        case .network(let message):
            return "Couldn't reach the license server — \(message)"
        case .storage(let message):
            return "Couldn't access secure license storage — \(message)"
        case .notActivated:
            return "No license is activated on this device."
        }
    }
}

@MainActor @Observable
public final class LicenseManager {
    public private(set) var state: LicenseState = .licensed(email: nil)
    public let isGated = false
    public private(set) var maskedLicenseKey: String?

    public var canDictate: Bool {
        switch state {
        case .licensed, .trialing: return true
        case .trialExpired, .licenseInvalid: return false
        }
    }

    public init() {}

    public func refresh() async {}

    public func activate(key: String) async throws(LicenseError) {}

    public func deactivate() async throws(LicenseError) {}
}
