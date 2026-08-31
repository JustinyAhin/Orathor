#if SETAPP
import Foundation
import Observation
import Setapp

@Observable
final class AppLicenseManager {
    enum State: Equatable {
        case licensed(email: String?)
        case trialing(daysLeft: Int)
        case trialExpired
        case licenseInvalid(reason: String)
    }

    enum MembershipStatus: Equatable {
        case checking
        case active(expirationDate: Date?)
        case inactive
    }

    private(set) var state: State = .licensed(email: nil)
    private(set) var membershipStatus: MembershipStatus = .checking
    let isGated = false
    let maskedLicenseKey: String? = nil

    @ObservationIgnored
    private var subscriptionObserver: NSObjectProtocol?

    var canDictate: Bool {
        switch membershipStatus {
        case .checking, .active:
            true
        case .inactive:
            false
        }
    }

    init() {
        subscriptionObserver = NotificationCenter.default.addObserver(
            forName: SetappManager.didChangeSubscriptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateSubscriptionStatus()
            }
        }
        updateSubscriptionStatus()
    }

    deinit {
        if let subscriptionObserver {
            NotificationCenter.default.removeObserver(subscriptionObserver)
        }
    }

    func refresh() async {
        updateSubscriptionStatus()
    }

    private func updateSubscriptionStatus() {
        guard let subscription = SetappManager.shared.subscription else {
            membershipStatus = .checking
            state = .licensed(email: nil)
            return
        }

        if subscription.isActive {
            membershipStatus = .active(expirationDate: subscription.expirationDate)
            state = .licensed(email: nil)
        } else {
            membershipStatus = .inactive
            state = .licenseInvalid(reason: "Your Setapp membership is inactive.")
        }
    }
}
#else
import OrathorLicensing

typealias AppLicenseManager = LicenseManager
#endif
