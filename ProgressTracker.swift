// ProgressTracker.swift
// Parse `dd` status output lines like "12345+0 records in"

import Foundation

struct DDProgressParser {
    static func parse(line: String) -> (fraction: Double, status: String)? {
        // TODO: extract bytes transferred, compute fraction based on device size
        return nil
    }
}
