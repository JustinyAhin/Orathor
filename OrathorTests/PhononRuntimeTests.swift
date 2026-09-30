import XCTest

@testable import Orathor

@MainActor
final class PhononRuntimeTests: XCTestCase {
    func testIncompleteInstallationCannotBeSelectedAsReady() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "orathor-phonon-marker-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let version = root.appending(path: PhononRuntime.runtimeVersion)
        try FileManager.default.createDirectory(at: version, withIntermediateDirectories: true)
        try PhononRuntime.runtimeVersion.write(
            to: version.appending(path: "installed.txt"), atomically: true, encoding: .utf8)
        let runtime = PhononRuntime(rootURL: root)
        XCTAssertFalse(runtime.isInstalled)
        XCTAssertThrowsError(try runtime.configuration())
    }

    func testInstallerResourcesAreBundledWithTheApp() throws {
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: try PhononRuntime.resource("phonon_worker", extension: "py").path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: try PhononRuntime.resource("phonon-requirements", extension: "txt").path))
        XCTAssertNotNil(Bundle.main.url(forResource: "Phonon-2-NOTICE", withExtension: "txt"))
    }

    func testCancellingSetupTerminatesTheActiveProcess() async throws {
        let log = FileManager.default.temporaryDirectory.appending(
            path: "orathor-phonon-cancel-\(UUID()).log")
        defer { try? FileManager.default.removeItem(at: log) }
        let task = Task {
            try await PhononSetupProcess.run(
                URL(filePath: "/bin/sleep"), arguments: ["30"], environment: [:], logURL: log)
        }
        try await Task.sleep(for: .milliseconds(100))
        let cancelledAt = Date()
        task.cancel()
        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertLessThan(Date().timeIntervalSince(cancelledAt), 2)
    }
}
