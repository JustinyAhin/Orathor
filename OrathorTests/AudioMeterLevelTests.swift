import XCTest

@testable import Orathor

final class AudioMeterLevelTests: XCTestCase {
    func testNormalizedLevelsAreClampedAndQuantized() {
        XCTAssertEqual(AudioMeterLevel(normalized: -0.5), .silence)
        XCTAssertEqual(AudioMeterLevel(normalized: .nan), .silence)
        XCTAssertEqual(AudioMeterLevel(normalized: 0), .silence)
        XCTAssertEqual(AudioMeterLevel(normalized: 0.01).step, 1)
        XCTAssertEqual(AudioMeterLevel(normalized: 0.5).step, 6)
        XCTAssertEqual(AudioMeterLevel(normalized: 1).step, 12)
        XCTAssertEqual(AudioMeterLevel(normalized: 2).step, 12)
    }

    func testStepInitializerAndNormalizedValueStayInRange() {
        XCTAssertEqual(AudioMeterLevel(step: -1), .silence)
        XCTAssertEqual(AudioMeterLevel(step: 20).step, AudioMeterLevel.stepCount)
        XCTAssertEqual(AudioMeterLevel(step: 3).normalized, 0.25)
    }

    func testAccumulatorCoalescesToLatestChangedStep() {
        let accumulator = AudioMeterAccumulator()
        accumulator.submit(AudioMeterLevel(step: 2))
        accumulator.submit(AudioMeterLevel(step: 8))

        XCTAssertEqual(accumulator.takePending(), AudioMeterLevel(step: 8))
        XCTAssertNil(accumulator.takePending())
        accumulator.submit(AudioMeterLevel(step: 8))
        XCTAssertNil(accumulator.takePending())
    }

    func testAccumulatorResetClearsPendingState() {
        let accumulator = AudioMeterAccumulator()
        accumulator.submit(AudioMeterLevel(step: 4))
        accumulator.reset()

        XCTAssertNil(accumulator.takePending())
        accumulator.submit(.silence)
        XCTAssertNil(accumulator.takePending())
        accumulator.submit(AudioMeterLevel(step: 1))
        XCTAssertEqual(accumulator.takePending(), AudioMeterLevel(step: 1))
    }
}
