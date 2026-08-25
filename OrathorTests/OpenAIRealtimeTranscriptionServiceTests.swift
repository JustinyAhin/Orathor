import XCTest

@testable import Orathor

final class OpenAIRealtimeTranscriptionServiceTests: XCTestCase {
  func testRuntimeDetectsXCTest() {
    XCTAssertTrue(AppRuntime.isRunningTests)
  }

  func testContextNormalizesAndMapsLegacyMulti() {
    let context = TranscriptionContext(
      prompt: "  hello  ", keywords: [" name ", "name", "", "term"],
      languages: .expected([" en ", "en", "fr"]))
    XCTAssertEqual(context.prompt, "hello")
    XCTAssertEqual(context.keywords, ["name", "term"])
    XCTAssertEqual(context.languages, .expected(["en", "fr"]))
    XCTAssertEqual(TranscriptionContext.fromLegacyLanguage("multi").languages, .automatic)
    XCTAssertEqual(TranscriptionContext.fromLegacyLanguage("en").languages, .expected(["en"]))
  }

  func testPayloadUsesLanguagesArrayAndOmitsEmptyHints() throws {
    let payload = OpenAIRealtimeTranscriptionService.sessionUpdatePayload(
      context: TranscriptionContext(), delay: "low")
    let data = try JSONSerialization.data(withJSONObject: payload)
    let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let transcription = try transcription(from: root)
    XCTAssertEqual(transcription["model"] as? String, "gpt-live-transcribe")
    XCTAssertEqual(transcription["delay"] as? String, "low")
    XCTAssertNil(transcription["language"])
    XCTAssertNil(transcription["languages"])
    XCTAssertNil(transcription["prompt"])
    XCTAssertNil(transcription["keywords"])
    let input = try input(from: root)
    let format = try XCTUnwrap(input["format"] as? [String: Any])
    XCTAssertEqual(format["type"] as? String, "audio/pcm")
    XCTAssertEqual(format["rate"] as? Int, 24_000)
    XCTAssertTrue(input["turn_detection"] is NSNull)
  }

  func testPayloadEmitsFixedAndMultipleLanguagesAndHints() throws {
    let fixed = OpenAIRealtimeTranscriptionService.sessionUpdatePayload(
      context: TranscriptionContext(languages: .expected(["en"])), delay: "minimal")
    XCTAssertEqual(try transcription(from: fixed)["languages"] as? [String], ["en"])
    let context = TranscriptionContext(
      prompt: "Names", keywords: ["Orathor", "Swift"], languages: .expected(["en", "fr"]))
    let transcription = try transcription(
      from: OpenAIRealtimeTranscriptionService.sessionUpdatePayload(context: context, delay: "low"))
    XCTAssertEqual(transcription["languages"] as? [String], ["en", "fr"])
    XCTAssertEqual(transcription["prompt"] as? String, "Names")
    XCTAssertEqual(transcription["keywords"] as? [String], ["Orathor", "Swift"])
  }

  func testInvalidKeywordAndCacheIdentity() {
    XCTAssertTrue(TranscriptionContext(keywords: ["bad<keyword"]).hasInvalidOpenAIKeywords)
    let context = TranscriptionContext(languages: .expected(["en"]))
    let first = SpeechServiceConfig(
      engine: .openAIWhisper, deepgramAPIKey: "", openAIAPIKey: "key", language: "en",
      context: context, openAITranscriptionDelay: "low")
    let changedContext = SpeechServiceConfig(
      engine: .openAIWhisper, deepgramAPIKey: "", openAIAPIKey: "key", language: "en",
      context: TranscriptionContext(languages: .expected(["fr"])), openAITranscriptionDelay: "low")
    let changedDelay = SpeechServiceConfig(
      engine: .openAIWhisper, deepgramAPIKey: "", openAIAPIKey: "key", language: "en",
      context: context, openAITranscriptionDelay: "minimal")
    XCTAssertNotEqual(first, changedContext)
    XCTAssertNotEqual(first, changedDelay)
  }

  func testAssemblerReplacesDeltaAndPreservesOrderAndIsolation() {
    var assembler = OpenAITranscriptAssembler()
    XCTAssertEqual(assembler.applyingDelta("hello", itemID: "one"), "hello")
    XCTAssertEqual(assembler.applyingCompleted("Hello", itemID: "one"), "Hello")
    XCTAssertEqual(assembler.applyingDelta("world", itemID: "two"), "Hello world")
    XCTAssertEqual(assembler.applyingCompleted("World!", itemID: "two"), "Hello World!")
    var separate = OpenAITranscriptAssembler()
    XCTAssertEqual(separate.applyingDelta("only this", itemID: "other"), "only this")
  }

  func testFinalizationAcceptsOnlyTheCommittedRecording() {
    var finalization = OpenAITranscriptFinalization()
    finalization.begin()

    XCTAssertEqual(finalization.registerCommittedItem("current"), .waiting)
    XCTAssertEqual(
      finalization.registerCompletedTranscript("old words", itemID: "previous"), .ignored)
    XCTAssertEqual(
      finalization.registerCompletedTranscript("current words", itemID: "current"),
      .apply(itemID: "current", transcript: "current words"))
  }

  func testFinalizationMatchesCompletionThatArrivesBeforeCommitAcknowledgement() {
    var finalization = OpenAITranscriptFinalization()
    finalization.begin()

    XCTAssertEqual(
      finalization.registerCompletedTranscript("finished", itemID: "current"), .waiting)
    XCTAssertEqual(
      finalization.registerCommittedItem("current"),
      .apply(itemID: "current", transcript: "finished"))
  }

  func testFinalizationRejectsEventsOutsideAnActiveStop() {
    var finalization = OpenAITranscriptFinalization()
    XCTAssertEqual(finalization.registerCommittedItem("old"), .ignored)
    XCTAssertEqual(finalization.registerCompletedTranscript("old words", itemID: "old"), .ignored)
  }

  func testErrorFormattingRetainsCodeAndMessage() {
    XCTAssertEqual(
      OpenAIRealtimeTranscriptionService.OpenAIRealtimeTranscriptionError.formattedMessage(
        code: "bad_request", message: "Invalid audio"), "OpenAI error (bad_request): Invalid audio")
    XCTAssertEqual(
      OpenAIRealtimeTranscriptionService.OpenAIRealtimeTranscriptionError.formattedMessage(
        code: "insufficient_quota", message: nil),
      "OpenAI transcription failed (insufficient_quota).")
    XCTAssertEqual(
      OpenAIRealtimeTranscriptionService.OpenAIRealtimeTranscriptionError.formattedMessage(
        code: nil, message: nil), "OpenAI transcription failed.")
  }

  func testProviderErrorClassificationOnlyRetriesTemporaryServiceFailures() {
    XCTAssertEqual(
      OpenAIRealtimeTranscriptionService.failureKind(for: "server_error"), .transient)
    XCTAssertEqual(
      OpenAIRealtimeTranscriptionService.failureKind(for: "service_unavailable"), .transient)
    XCTAssertEqual(
      OpenAIRealtimeTranscriptionService.failureKind(for: "insufficient_quota"), .nonRecoverable)
    XCTAssertEqual(
      OpenAIRealtimeTranscriptionService.failureKind(for: "rate_limit_exceeded"), .nonRecoverable)
    XCTAssertEqual(
      OpenAIRealtimeTranscriptionService.failureKind(for: "invalid_request_error"), .nonRecoverable)
  }

  func testFallbackPolicyRequiresTransientCloudFailure() {
    let transient = TranscriptionFailure(kind: .transient, message: "Offline")
    let permanent = TranscriptionFailure(kind: .nonRecoverable, message: "Bad key")

    XCTAssertTrue(
      TranscriptionFallbackPolicy.shouldFallback(
        requestedEngine: .deepgram, failure: transient))
    XCTAssertTrue(
      TranscriptionFallbackPolicy.shouldFallback(
        requestedEngine: .openAIWhisper, failure: transient))
    XCTAssertFalse(
      TranscriptionFallbackPolicy.shouldFallback(
        requestedEngine: .apple, failure: transient))
    XCTAssertFalse(
      TranscriptionFallbackPolicy.shouldFallback(
        requestedEngine: .deepgram, failure: permanent))
    XCTAssertEqual(
      TranscriptionFallbackPolicy.failureKind(forHTTPStatus: nil), .transient)
    XCTAssertEqual(
      TranscriptionFallbackPolicy.failureKind(forHTTPStatus: 503), .transient)
    XCTAssertEqual(
      TranscriptionFallbackPolicy.failureKind(forHTTPStatus: 401), .nonRecoverable)
    XCTAssertEqual(
      TranscriptionFallbackPolicy.failureKind(forHTTPStatus: 429), .nonRecoverable)
  }

  func testLegacyTranscriptEntryDecodesAsCompleteWithoutFallbackMetadata() throws {
    let json = """
      {
        "id": "00000000-0000-0000-0000-000000000001",
        "text": "Legacy transcript",
        "timestamp": 0,
        "durationSeconds": 2,
        "wordCount": 2,
        "engine": "deepgram"
      }
      """

    let entry = try JSONDecoder().decode(
      TranscriptEntry.self, from: try XCTUnwrap(json.data(using: .utf8)))
    XCTAssertNil(entry.status)
    XCTAssertNil(entry.requestedEngine)
    XCTAssertNil(entry.failureMessage)
    XCTAssertEqual(entry.engine, .deepgram)
  }

  func testFallbackAndFailedEntriesRetainOutcomeMetadata() {
    let fallback = TranscriptEntry(
      text: "Recovered", timestamp: Date(), durationSeconds: 1, wordCount: 1,
      targetAppName: nil, targetAppBundleID: nil, engine: .apple,
      requestedEngine: .openAIWhisper, status: .complete)
    let failed = TranscriptEntry(
      text: "", timestamp: Date(), durationSeconds: 1, wordCount: 0,
      targetAppName: nil, targetAppBundleID: nil, audioFileName: "recording.m4a",
      engine: nil, requestedEngine: .deepgram, status: .failed,
      failureMessage: "Local model unavailable")

    XCTAssertNotEqual(fallback.engine, fallback.requestedEngine)
    XCTAssertEqual(failed.status, .failed)
    XCTAssertEqual(failed.audioFileName, "recording.m4a")
  }

  private func transcription(from payload: [String: Any]) throws -> [String: Any] {
    let input = try input(from: payload)
    return try XCTUnwrap(input["transcription"] as? [String: Any])
  }

  private func input(from payload: [String: Any]) throws -> [String: Any] {
    let session = try XCTUnwrap(payload["session"] as? [String: Any])
    let audio = try XCTUnwrap(session["audio"] as? [String: Any])
    return try XCTUnwrap(audio["input"] as? [String: Any])
  }
}
