import AVFoundation
import XCTest

@testable import Orathor

@MainActor
final class PhononSpeechServiceTests: XCTestCase {
    private func makeService(_ worker: FakePhononWorker) -> PhononSpeechService {
        PhononSpeechService(worker: worker) {
            PhononConfiguration(
                pythonURL: URL(filePath: "/unused/python"), helperURL: URL(filePath: "/unused/helper"),
                modelURL: URL(filePath: "/unused/model"), environment: [:],
                logURL: URL(filePath: "/unused/log"))
        }
    }

    func testStopDrainsFullFramesAndShortTailBeforeFinalization() async throws {
        let worker = FakePhononWorker()
        let service = makeService(worker)
        try await service.startTranscribing()
        let data = Data(repeating: 0, count: 3200 * 3 + 44)
        service.processAudioData(data)
        let result = await service.stopTranscribing()
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(worker.audio.reduce(0) { $0 + $1.count }, data.count)
        XCTAssertEqual(worker.operations.last, "finish")
        XCTAssertEqual(service.transcribedText, "Finished transcript")
        XCTAssertFalse(service.isTranscribing)
        XCTAssertEqual(worker.shutdownCount, 0, "Keep the engine warm between recordings")
        service.shutdown()
    }

    func testLatePartialCannotChangeTheNextRecording() async throws {
        let worker = FakePhononWorker()
        let service = makeService(worker)
        try await service.startTranscribing()
        let oldSession = try XCTUnwrap(worker.sessions.last)
        _ = await service.stopTranscribing()
        try await service.startTranscribing()
        let newSession = try XCTUnwrap(worker.sessions.last)
        worker.onPartial?(oldSession, "Stale words")
        XCTAssertEqual(service.transcribedText, "")
        worker.onPartial?(newSession, "Current words")
        XCTAssertEqual(service.transcribedText, "Current words")
        service.shutdown()
        worker.onPartial?(newSession, "Cancelled words")
        XCTAssertEqual(service.transcribedText, "Current words")
    }

    func testPreloadedModelStartsWithoutPreparingAgain() async throws {
        let worker = FakePhononWorker()
        let service = makeService(worker)
        defer { service.shutdown() }
        var preparationStates: [Bool] = []
        service.onPreparingChanged = { preparationStates.append($0) }
        try await service.prepare()
        XCTAssertEqual(preparationStates, [true, false])
        preparationStates.removeAll()
        for _ in 0..<2 {
            try await service.startTranscribing()
            let outcome = await service.stopTranscribing()
            XCTAssertEqual(outcome, .completed)
        }
        XCTAssertEqual(worker.prepareCount, 1)
        XCTAssertTrue(preparationStates.isEmpty, "A ready engine must not display preparation")
        XCTAssertTrue(worker.isReady)
        XCTAssertEqual(worker.shutdownCount, 0)
    }

    func testShutdownReleasesTheModelAndNextUsePreparesAgain() async throws {
        let worker = FakePhononWorker()
        let service = makeService(worker)
        defer { service.shutdown() }
        try await service.prepare()
        service.shutdown()
        XCTAssertFalse(worker.isReady)
        try await service.startTranscribing()
        XCTAssertEqual(worker.prepareCount, 2)
        XCTAssertTrue(worker.isReady)
        let outcome = await service.stopTranscribing()
        XCTAssertEqual(outcome, .completed)
    }

    func testRuntimeFailureIsReportedOnceAndPreservesPartialForFallback() async throws {
        let worker = FakePhononWorker()
        let service = makeService(worker)
        var failures: [TranscriptionFailure] = []
        service.onFailure = { failures.append($0) }
        try await service.startTranscribing()
        worker.onPartial?(try XCTUnwrap(worker.sessions.last), "Partial words")
        worker.feedError = TranscriptionFailure(kind: .transient, message: "Worker died")
        service.processAudioData(Data(repeating: 0, count: 3200))
        let result = await service.stopTranscribing()
        XCTAssertEqual(result, .failed(TranscriptionFailure(kind: .transient, message: "Worker died")))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(service.transcribedText, "Partial words")
        XCTAssertTrue(
            TranscriptionFallbackPolicy.shouldFallback(requestedEngine: .phonon, failure: failures.first))
        service.shutdown()
    }

    func testPreparationFailureLeavesNoActiveRecording() async {
        let worker = FakePhononWorker()
        worker.prepareError = TranscriptionFailure(kind: .nonRecoverable, message: "Missing model")
        let service = makeService(worker)
        do {
            try await service.startTranscribing()
            XCTFail("Expected a setup failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Missing model")
        }
        XCTAssertFalse(service.isTranscribing)
        XCTAssertTrue(worker.sessions.isEmpty)
        XCTAssertEqual(worker.shutdownCount, 1)
    }

    func testShutdownDuringPreparationDoesNotStartARecording() async throws {
        let worker = FakePhononWorker()
        worker.holdPreparation = true
        let service = makeService(worker)
        let start = Task { try await service.startTranscribing() }
        while worker.prepareContinuation == nil { await Task.yield() }
        service.shutdown()
        worker.prepareContinuation?.resume()
        worker.prepareContinuation = nil
        do {
            try await start.value
            XCTFail("Cancelled preparation must not start")
        } catch {}
        XCTAssertFalse(service.isTranscribing)
        XCTAssertTrue(worker.sessions.isEmpty)
    }

    func testResamplesMicrophoneAudioAndKeepsFloatSamples() throws {
        let queue = PhononAudioQueue()
        queue.begin(session: UUID())
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false))
        for _ in 0..<48 {
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1000))
            buffer.frameLength = 1000
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            for i in 0..<1000 { samples[i] = 0.1 }
            XCTAssertEqual(queue.capture(buffer), .accepted)
        }
        queue.end()
        var count = 0
        while let frame = queue.takeFrame(flush: true) { count += frame.count / 4 }
        XCTAssertEqual(Double(count), 16_000, accuracy: 64)
    }

    func testBacklogIsBoundedAndInactiveAudioIsIgnored() {
        let queue = PhononAudioQueue()
        XCTAssertEqual(queue.append(Data(repeating: 0, count: 4)), .inactive)
        queue.begin(session: UUID())
        XCTAssertEqual(queue.append(Data(repeating: 0, count: 16_000 * 4 * 30)), .accepted)
        XCTAssertEqual(queue.append(Data(repeating: 0, count: 4)), .overflow)
        queue.clear()
        XCTAssertNil(queue.takeFrame(flush: true))
        queue.begin(session: UUID())
        XCTAssertEqual(queue.append(Data(repeating: 0, count: 3)), .invalidFormat)
    }

    func testHistoryKeepsPhononRequestAndAppleFallbackAttribution() throws {
        for output in [SpeechEngine.phonon, .apple] {
            let entry = TranscriptEntry(
                text: "Saved words", timestamp: Date(), durationSeconds: 2,
                wordCount: 2, targetAppName: nil, targetAppBundleID: nil,
                engine: output, requestedEngine: .phonon)
            let encoded = try JSONEncoder().encode(entry)
            let restored = try JSONDecoder().decode(TranscriptEntry.self, from: encoded)
            XCTAssertEqual(restored.engine, output)
            XCTAssertEqual(restored.requestedEngine, .phonon)
            XCTAssertEqual(restored.status, .complete)
        }
    }
}

@MainActor
private final class FakePhononWorker: PhononWorkerControlling {
    var isReady = false
    var prepareCount = 0
    var onPartial: ((UUID, String) -> Void)?
    var onFailure: ((TranscriptionFailure) -> Void)?
    var sessions: [UUID] = []
    var audio: [Data] = []
    var operations: [String] = []
    var shutdownCount = 0
    var prepareError: Error?
    var feedError: Error?
    var holdPreparation = false
    var prepareContinuation: CheckedContinuation<Void, Never>?
    func prepare(configuration: PhononConfiguration) async throws {
        prepareCount += 1
        if let prepareError { throw prepareError }
        if holdPreparation { await withCheckedContinuation { prepareContinuation = $0 } }
        isReady = true
    }
    func start(session: UUID) async throws {
        sessions.append(session)
        operations.append("start")
    }
    func feed(_ data: Data, session: UUID) async throws {
        if let feedError { throw feedError }
        audio.append(data)
        operations.append("audio")
    }
    func finish(session: UUID) async throws -> String {
        operations.append("finish")
        return "Finished transcript"
    }
    func shutdown() {
        isReady = false
        shutdownCount += 1
    }
}
