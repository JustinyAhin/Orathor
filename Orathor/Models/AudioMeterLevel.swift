import Foundation

nonisolated struct AudioMeterLevel: Equatable, Sendable {
    static let stepCount = 12
    static let silence = AudioMeterLevel(step: 0)

    let step: Int

    init(step: Int) {
        self.step = min(max(step, 0), Self.stepCount)
    }

    init(normalized: Float) {
        guard normalized.isFinite, normalized > 0 else {
            self = .silence
            return
        }
        let clamped = min(normalized, 1)
        self.init(step: Int(ceil(clamped * Float(Self.stepCount))))
    }

    var normalized: Float {
        Float(step) / Float(Self.stepCount)
    }
}
