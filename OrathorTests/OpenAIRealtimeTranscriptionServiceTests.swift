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
