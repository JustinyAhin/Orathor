import Foundation

/// Provider-neutral hints captured when a transcription service is created.
struct TranscriptionContext: Equatable, Hashable, Sendable {
  enum LanguageSelection: Equatable, Hashable, Sendable {
    case automatic
    case expected([String])
  }

  let prompt: String?
  let keywords: [String]
  let languages: LanguageSelection

  init(prompt: String? = nil, keywords: [String] = [], languages: LanguageSelection = .automatic) {
    self.prompt = Self.normalizedOptional(prompt)
    self.keywords = Self.normalized(keywords)
    switch languages {
    case .automatic:
      self.languages = .automatic
    case .expected(let languages):
      let normalized = Self.normalized(languages)
      self.languages = normalized.isEmpty ? .automatic : .expected(normalized)
    }
  }

  static func fromLegacyLanguage(_ language: String) -> TranscriptionContext {
    let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines)
    return TranscriptionContext(
      languages: normalized == "multi" || normalized.isEmpty ? .automatic : .expected([normalized]))
  }

  var hasInvalidOpenAIKeywords: Bool {
    keywords.contains {
      $0.contains("<") || $0.contains(">") || $0.contains("\r") || $0.contains("\n")
    }
  }

  private static func normalizedOptional(_ value: String?) -> String? {
    guard let value else { return nil }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? nil : normalized
  }

  private static func normalized(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.compactMap { value in
      let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
      return normalized
    }
  }
}
