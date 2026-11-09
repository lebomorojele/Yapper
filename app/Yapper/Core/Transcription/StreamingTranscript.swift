import Foundation

struct StreamingTranscript {
    private var segments: [Int: String] = [:]

    var text: String {
        segments.sorted { $0.key < $1.key }.map { $0.value }.joined(separator: " ")
    }

    mutating func update(segment: Int, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        segments[segment] = trimmed
    }
}
