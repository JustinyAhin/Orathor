import Foundation

/// Immutable identity for a cached speech service and its captured configuration.
struct SpeechServiceConfig: Equatable {
  let engine: SpeechEngine
  let deepgramAPIKey: String
  let openAIAPIKey: String
  let language: String
  let context: TranscriptionContext
  let openAITranscriptionDelay: String
}
