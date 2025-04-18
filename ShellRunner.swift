// Helpers.swift
// Generic helper to spawn shell commands with real-time output

import Foundation

class ShellRunner {
    static func run(cmd: String,
                    args: [String],
                    progressParser: @escaping (String) -> (Double, String)?,
                    progress: @escaping (Double, String) -> Void,
                    completion: @escaping (Result<Void, Error>) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cmd)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let data = fh.availableData
            guard !data.isEmpty,
                  let line = String(data: data, encoding: .utf8) else { return }

            // dd prints progress on stderr, often without newlines,
            // so we may need to split on “\r” or “\n”
            line.components(separatedBy: CharacterSet.newlines).forEach { chunk in
                if let (fraction, status) = progressParser(chunk) {
                    DispatchQueue.main.async {
                        progress(fraction, status)
                    }
                }
            }
        }

        process.terminationHandler = { proc in
            handle.readabilityHandler = nil
            if proc.terminationStatus == 0 {
                completion(.success(()))
            } else {
                let err = NSError(domain: "ShellRunner",
                                  code: Int(proc.terminationStatus),
                                  userInfo: [NSLocalizedDescriptionKey: "Exited with code \(proc.terminationStatus)"])
                completion(.failure(err))
            }
        }

        do {
            try process.run()
        } catch {
            completion(.failure(error))
        }
    }
}

