import AVFoundation
import XCTest

@testable import Orathor

/// Opt-in: installs the production-managed runtime and replays private saved
/// recordings supplied through a local manifest. No audio belongs in the repo.
@MainActor
final class PhononIntegrationTests: XCTestCase {
    private struct Clip: Decodable {
        let id: String
        let wav: String
        let duration: Double
    }
    private struct Result: Encodable {
        let id: String
        let text: String
        let firstPartialSeconds: Double?
        let finalizationSeconds: Double
        let startSeconds: Double
        let idleBeforeSeconds: Double
        let processIdentifier: Int32
    }

    func testManagedSetupAndSavedRecordingReplay() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let manifestPath = environment["ORATHOR_PHONON_REPLAY_MANIFEST"] else {
            throw XCTSkip(
                "Set ORATHOR_PHONON_REPLAY_MANIFEST to a local saved-audio manifest to run real model inference."
            )
        }
        let clips = try JSONDecoder().decode([Clip].self, from: Data(contentsOf: URL(filePath: manifestPath)))
        XCTAssertFalse(clips.isEmpty)
        let runtime = PhononRuntime.shared
        if !runtime.isInstalled {
            runtime.install()
            let deadline = Date().addingTimeInterval(900)
            while runtime.isInstalling, Date() < deadline {
                try await Task.sleep(for: .milliseconds(250))
            }
            XCTAssertNil(runtime.errorMessage)
            XCTAssertTrue(runtime.isInstalled, runtime.installationMessage)
        }
        let configuration = try runtime.configuration()
        XCTAssertEqual(configuration.environment["HF_HUB_OFFLINE"], "1")
        let worker = PhononWorker()
        let service = PhononSpeechService(worker: worker) { configuration }
        defer { service.shutdown() }
        async let firstPreparation: Void = service.prepare()
        async let secondPreparation: Void = service.prepare()
        _ = try await (firstPreparation, secondPreparation)
        let processID = try XCTUnwrap(worker.processIdentifier)
        let idleSeconds = environment["ORATHOR_PHONON_REPLAY_IDLE_SECONDS"].flatMap(Double.init) ?? 0
        var preparationStates: [Bool] = []
        service.onPreparingChanged = { preparationStates.append($0) }
        var results: [Result] = []
        for (index, clip) in clips.enumerated() {
            let idleBefore = index == 1 ? idleSeconds : 0
            if idleBefore > 0 {
                NSLog("Phonon replay: waiting %.0f seconds between dictations", idleBefore)
                try await Task.sleep(for: .seconds(idleBefore))
                XCTAssertTrue(worker.isReady, "The selected model must stay ready while idle")
            }
            let keyDown = Date()
            try await service.startTranscribing()
            let startSeconds = Date().timeIntervalSince(keyDown)
            XCTAssertLessThan(startSeconds, 1, "A warm start must not reload the model")
            XCTAssertTrue(preparationStates.isEmpty, "Warm dictation must skip preparation UI")
            XCTAssertEqual(worker.processIdentifier, processID, "Reuse the model across dictations")
            let audio = try AVAudioFile(forReading: URL(filePath: clip.wav))
            let start = Date()
            var framesFed: AVAudioFramePosition = 0
            var firstPartial: Double?
            while framesFed < audio.length {
                let count = AVAudioFrameCount(min(800, audio.length - framesFed))
                let buffer = try XCTUnwrap(
                    AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: count))
                try audio.read(into: buffer, frameCount: count)
                service.processAudioBuffer(buffer)
                framesFed += AVAudioFramePosition(buffer.frameLength)
                let remaining = start.addingTimeInterval(
                    Double(framesFed) / audio.processingFormat.sampleRate
                ).timeIntervalSinceNow
                if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
                if firstPartial == nil, !service.transcribedText.isEmpty {
                    firstPartial = Date().timeIntervalSince(start)
                }
            }
            let stop = Date()
            let outcome = await service.stopTranscribing()
            XCTAssertEqual(outcome, .completed, clip.id)
            XCTAssertFalse(service.transcribedText.isEmpty, clip.id)
            XCTAssertNotNil(firstPartial, "Live partials must arrive before key-up for \(clip.id)")
            results.append(
                Result(
                    id: clip.id, text: service.transcribedText, firstPartialSeconds: firstPartial,
                    finalizationSeconds: Date().timeIntervalSince(stop), startSeconds: startSeconds,
                    idleBeforeSeconds: idleBefore, processIdentifier: processID))
        }
        if let outputPath = environment["ORATHOR_PHONON_REPLAY_OUTPUT"] {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(results).write(to: URL(filePath: outputPath), options: .atomic)
        }
        service.shutdown()
        XCTAssertNil(worker.processIdentifier)
    }
}
