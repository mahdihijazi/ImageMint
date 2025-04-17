// Helpers.swift
// Generic helper to spawn shell commands with real-time output

import Foundation

class ShellRunner {
    static func run(cmd: String,
                    args: [String],
                    progressParser: @escaping (String) -> (Double, String)?,
                    progress: @escaping (Double, String) -> Void,
                    completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Use Process() to launch command, pipe stdout, stderr
        // Feed each line to progressParser, call progress(), and on exit call completion()
    }
}
