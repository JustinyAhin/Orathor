import Observation
import ServiceManagement

enum LaunchAtLoginSystemStatus {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

protocol LaunchAtLoginControlling {
    var status: LaunchAtLoginSystemStatus { get }

    func register() throws
    func unregister() throws
    func openSystemSettings()
}

struct SystemLaunchAtLoginController: LaunchAtLoginControlling {
    private let service = SMAppService.mainApp

    var status: LaunchAtLoginSystemStatus {
        switch service.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .notFound
        @unknown default:
            .notFound
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

private struct UnavailableLaunchAtLoginController: LaunchAtLoginControlling {
    let status = LaunchAtLoginSystemStatus.notFound

    func register() throws {}
    func unregister() throws {}
    func openSystemSettings() {}
}

@Observable
final class LaunchAtLoginService {
    enum Status: Equatable {
        case disabled
        case enabled
        case requiresApproval
        case unavailable
    }

    private(set) var status: Status = .disabled
    private(set) var errorMessage: String?

    private let controller: any LaunchAtLoginControlling

    var isRegistered: Bool {
        status == .enabled || status == .requiresApproval
    }

    var isAvailable: Bool {
        status != .unavailable
    }

    init() {
        if AppRuntime.isRunningTests {
            controller = UnavailableLaunchAtLoginController()
        } else {
            controller = SystemLaunchAtLoginController()
        }
        refresh()
    }

    init(controller: any LaunchAtLoginControlling) {
        self.controller = controller
        refresh()
    }

    nonisolated deinit {}

    func refresh() {
        status = switch controller.status {
        case .notRegistered: .disabled
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        }
    }

    func setEnabled(_ isEnabled: Bool) {
        errorMessage = nil

        do {
            if isEnabled {
                guard controller.status == .notRegistered else {
                    refresh()
                    return
                }
                try controller.register()
            } else {
                guard controller.status != .notRegistered else {
                    refresh()
                    return
                }
                try controller.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
    }

    func openSystemSettings() {
        controller.openSystemSettings()
    }

    func clearError() {
        errorMessage = nil
    }
}
