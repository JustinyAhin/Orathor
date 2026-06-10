import Foundation
import FoundationModels

private let diag = DiagnosticLogger.shared

/// Optional on-device cleanup pass for finished transcripts, using Apple's
/// Foundation Models system language model. Engine-agnostic — runs on the final
/// string from any transcription engine. Always fails open: on any error or when
/// the model is unavailable, the original text is returned unchanged.
actor TranscriptPolisher {
    /// Human-readable label for the model that performs formatting. The system
    /// language model exposes no version identifier, so this is a stable descriptor.
    static let modelDescription = "Apple Foundation Models (on-device)"

    /// Current usability of on-device formatting, with a user-facing reason when
    /// unavailable. Read synchronously so the UI can disable the toggle and explain why.
    nonisolated static var status: (available: Bool, message: String?) {
        switch SystemLanguageModel.default.availability {
        case .available:
            return (true, nil)
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return (false, "Requires Apple Intelligence — turn it on in System Settings ▸ Apple Intelligence & Siri.")
            case .deviceNotEligible:
                return (false, "Not supported on this Mac.")
            case .modelNotReady:
                return (false, "Apple Intelligence model is still downloading. Try again shortly.")
            @unknown default:
                return (false, "On-device formatting is unavailable right now.")
            }
        }
    }

    private static let instructions = """
    You clean up dictated speech-to-text transcripts. Apply these edits and nothing more:
    - Fix capitalization and punctuation.
    - Remove filler words and verbal stumbles (um, uh, er, "you know", repeated words).
    - Apply spoken formatting commands: "new line" / "new paragraph" become line breaks.
    Preserve the speaker's wording and meaning. Do not summarize, answer, translate, \
    or add anything. Return ONLY the cleaned transcript text, with no preamble or commentary.
    """

    /// Returns a cleaned version of `raw`, or `raw` unchanged if cleanup is
    /// unavailable or fails. Never throws.
    func polish(_ raw: String) async -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return raw }

        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            diag.log("Polish skipped — model unavailable: \(String(describing: availability))")
            return raw
        }

        do {
            // Fresh session per call so transcripts don't bleed context into each other.
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(to: raw)
            let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                diag.log("Polish returned empty — keeping raw")
                return raw
            }
            diag.log("Polish OK — \(raw.count) → \(cleaned.count) chars")
            return cleaned
        } catch {
            diag.log("Polish failed — \(error)")
            return raw
        }
    }
}
