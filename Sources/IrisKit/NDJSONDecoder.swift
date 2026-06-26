import Foundation

public enum NDJSONDecoder {
    private static let jsonDecoder = JSONDecoder()

    /// Parse a single JSON line into a StreamEvent.
    /// Returns nil for blank / whitespace-only lines.
    public static func parseLine(_ line: String) throws -> StreamEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let data = trimmed.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Non-UTF-8 line"))
        }
        return try jsonDecoder.decode(StreamEvent.self, from: data)
    }

    /// Decode an array of raw NDJSON lines into StreamEvents.
    /// Blank lines are silently skipped; malformed lines surface their error.
    public static func decodeLines(_ lines: [String]) -> [StreamEvent] {
        var results: [StreamEvent] = []
        for line in lines {
            if let event = try? parseLine(line) {
                results.append(event)
            }
        }
        return results
    }
}
