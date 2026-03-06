import SwiftUI

enum TextHighlighter {
    static func highlight(_ text: String, query: String) -> AttributedString {
        var result = AttributedString(text)
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return result }
        var searchRange = result.startIndex..<result.endIndex
        while let range = result[searchRange].range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) {
            result[range].backgroundColor = .yellow.opacity(0.7)
            searchRange = range.upperBound..<result.endIndex
        }
        return result
    }
}
