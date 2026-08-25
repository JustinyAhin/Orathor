import XCTest

@testable import Orathor

@MainActor
final class RecordingOverlayLifecycleTests: XCTestCase {
    func testPresentationAndModeUpdatesAreIdempotent() {
        let sessionID = UUID()
        var lifecycle = RecordingOverlayController.Lifecycle()

        XCTAssertEqual(lifecycle.presentation, .idle)
        XCTAssertTrue(lifecycle.present(sessionID: sessionID, mode: .starting))
        XCTAssertFalse(lifecycle.present(sessionID: sessionID, mode: .starting))
        XCTAssertFalse(lifecycle.update(mode: .starting, sessionID: sessionID))
        XCTAssertTrue(lifecycle.update(mode: .recording, sessionID: sessionID))
        XCTAssertEqual(
            lifecycle.presentation,
            .visible(sessionID: sessionID, mode: .recording)
        )
    }

    func testStaleSessionCannotUpdateOrDismissNewPresentation() {
        let oldSessionID = UUID()
        let newSessionID = UUID()
        var lifecycle = RecordingOverlayController.Lifecycle()

        XCTAssertTrue(lifecycle.present(sessionID: oldSessionID, mode: .starting))
        XCTAssertTrue(lifecycle.present(sessionID: newSessionID, mode: .starting))
        XCTAssertFalse(lifecycle.update(mode: .error("Old error"), sessionID: oldSessionID))
        XCTAssertFalse(lifecycle.dismiss(sessionID: oldSessionID))
        XCTAssertEqual(
            lifecycle.presentation,
            .visible(sessionID: newSessionID, mode: .starting)
        )
    }

    func testDismissalIsIdempotent() {
        let sessionID = UUID()
        var lifecycle = RecordingOverlayController.Lifecycle()

        XCTAssertTrue(lifecycle.present(sessionID: sessionID, mode: .recording))
        XCTAssertTrue(lifecycle.dismiss(sessionID: sessionID))
        XCTAssertFalse(lifecycle.dismiss(sessionID: sessionID))
        XCTAssertEqual(lifecycle.presentation, .idle)
    }

    func testFallbackModesRemainInTheSameRecordingSession() {
        let sessionID = UUID()
        var lifecycle = RecordingOverlayController.Lifecycle()

        XCTAssertTrue(lifecycle.present(sessionID: sessionID, mode: .recording))
        XCTAssertTrue(lifecycle.update(mode: .recordingWithFallback, sessionID: sessionID))
        XCTAssertTrue(lifecycle.update(mode: .transcribingLocally, sessionID: sessionID))
        XCTAssertEqual(
            lifecycle.presentation,
            .visible(sessionID: sessionID, mode: .transcribingLocally)
        )
    }
}
