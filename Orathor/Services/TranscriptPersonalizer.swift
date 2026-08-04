import Foundation

struct TranscriptPersonalizer {
    private struct Candidate {
        let source: String
        let replacement: String
        let priority: Int
    }

    func personalize(_ text: String, using snapshot: PersonalDictionarySnapshot) -> String {
        guard !text.isEmpty else { return text }

        var seen = Set<String>()
        var candidates: [Candidate] = []

        for rule in snapshot.replacements {
            let key = Self.key(rule.source)
            guard seen.insert(key).inserted else { continue }
            candidates.append(Candidate(source: rule.source, replacement: rule.replacement, priority: 0))
        }
        for term in snapshot.terms {
            let key = Self.key(term)
            guard seen.insert(key).inserted else { continue }
            candidates.append(Candidate(source: term, replacement: term, priority: 1))
        }
        candidates.sort {
            if $0.source.count != $1.source.count { return $0.source.count > $1.source.count }
            return $0.priority < $1.priority
        }
        guard !candidates.isEmpty else { return text }

        let alternatives = candidates.map { NSRegularExpression.escapedPattern(for: $0.source) }
        let pattern = "(?<![\\p{L}\\p{N}_])(?:\(alternatives.joined(separator: "|")))(?![\\p{L}\\p{N}_])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }

        let replacements = Dictionary(uniqueKeysWithValues: candidates.map { (Self.key($0.source), $0.replacement) })
        let result = NSMutableString(string: text)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let matched = String(text[range])
            guard let replacement = replacements[Self.key(matched)] else { continue }
            result.replaceCharacters(in: match.range, with: replacement)
        }
        return result as String
    }

    private static func key(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
