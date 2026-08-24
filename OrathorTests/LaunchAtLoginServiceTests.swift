import XCTest

@testable import Orathor

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {
    func testMapsSystemStatuses() {
        let controller = FakeLaunchAtLoginController(status: .notRegistered)
        let service = LaunchAtLoginService(controller: controller)

        XCTAssertEqual(service.status, .disabled)

        controller.status = .enabled
        service.refresh()
        XCTAssertEqual(service.status, .enabled)

        controller.status = .requiresApproval
        service.refresh()
        XCTAssertEqual(service.status, .requiresApproval)
        XCTAssertTrue(service.isRegistered)

        controller.status = .notFound
        service.refresh()
        XCTAssertEqual(service.status, .unavailable)
        XCTAssertFalse(service.isAvailable)
    }

    func testEnablingRegistersAndRefreshesStatus() {
        let controller = FakeLaunchAtLoginController(status: .notRegistered)
        let service = LaunchAtLoginService(controller: controller)

        service.setEnabled(true)

        XCTAssertEqual(controller.registerCallCount, 1)
        XCTAssertEqual(service.status, .enabled)
        XCTAssertTrue(service.isRegistered)
    }

    func testDisablingUnregistersApprovalRequiredService() {
        let controller = FakeLaunchAtLoginController(status: .requiresApproval)
        let service = LaunchAtLoginService(controller: controller)

        service.setEnabled(false)

        XCTAssertEqual(controller.unregisterCallCount, 1)
        XCTAssertEqual(service.status, .disabled)
    }

    func testRegistrationFailureIsPresentedAndActualStatusIsPreserved() {
        let controller = FakeLaunchAtLoginController(status: .notRegistered)
        controller.registerError = TestError.registrationFailed
        let service = LaunchAtLoginService(controller: controller)

        service.setEnabled(true)

        XCTAssertEqual(service.status, .disabled)
        XCTAssertEqual(service.errorMessage, TestError.registrationFailed.localizedDescription)

        service.clearError()
        XCTAssertNil(service.errorMessage)
    }

    func testOpensSystemSettings() {
        let controller = FakeLaunchAtLoginController(status: .requiresApproval)
        let service = LaunchAtLoginService(controller: controller)

        service.openSystemSettings()

        XCTAssertEqual(controller.openSystemSettingsCallCount, 1)
    }
}

@MainActor
private final class FakeLaunchAtLoginController: LaunchAtLoginControlling {
    var status: LaunchAtLoginSystemStatus
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var openSystemSettingsCallCount = 0

    init(status: LaunchAtLoginSystemStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }

    func openSystemSettings() {
        openSystemSettingsCallCount += 1
    }
}

private enum TestError: LocalizedError {
    case registrationFailed

    var errorDescription: String? {
        "Registration failed"
    }
}
