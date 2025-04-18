// ProgressTracker.swift
// Parse `dd` status output lines like "12345+0 records in"

import Foundation

struct DDProgressParser {
    static func parse(line: String) -> (fraction: Double, status: String)? {
        // Look for “12345678 bytes”
        let pattern = #"^\s*([0-9]+)\s+bytes"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, options: [], range: .init(location: 0, length: line.utf16.count)),
              let bytesRange = Range(match.range(at: 1), in: line),
              let bytes = Double(line[bytesRange]) else {
            return nil
        }

        // fraction = bytes / total_size (we’ll capture total_size when we call backup)
        // for now return fraction=bytes (we’ll divide later) and raw status
        return (bytes, line.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
