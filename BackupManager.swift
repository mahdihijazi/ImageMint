// BackupManager.swift
// Orchestrates unmount → dd backup → remount

import Foundation

class BackupManager {
    // Block size for raw copy (tune as needed: "4m", "8m", "16m", etc.)
    private static let blockSize = "8m"
    
    /// Unmounts the entire disk for raw device access
    static func unmount(device: Device,
                        completion: @escaping (Result<Void, Error>) -> Void) {
        // Strip the 'r' from /dev/rdiskX to get /dev/diskX
        let disk = device.identifier.replacingOccurrences(of: "r", with: "")
        ShellRunner.run(
            cmd: "/usr/sbin/diskutil",
            args: ["unmountDisk", disk],
            progressParser: { _ in nil },
            progress: { _, _ in },
            completion: completion
        )
    }

    /// Performs the raw `dd` backup, reporting progress back to the UI
    static func performDDBackup(device: Device,
                                to url: URL,
                                progress: @escaping (Double, String) -> Void,
                                completion: @escaping (Result<Void, Error>) -> Void) {
        ShellRunner.run(
            cmd: "/bin/dd",
            args: [
                "if=\(device.identifier)",
                "of=\(url.path)",
                "bs=\(blockSize)",
                "status=progress"
            ],
            progressParser: { line in
                // Parse “123456 bytes” from dd’s output
                guard let (rawBytes, status) = DDProgressParser.parse(line: line) else {
                    return nil
                }
                // Compute fraction
                let fraction = rawBytes / Double(device.size)
                return (fraction, status)
            },
            progress: progress
        ) { result in
            completion(result)
        }
    }

    /// Remounts the disk after the raw write is done
    static func mount(device: Device,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        let disk = device.identifier.replacingOccurrences(of: "r", with: "")
        ShellRunner.run(
            cmd: "/usr/sbin/diskutil",
            args: ["mountDisk", disk],
            progressParser: { _ in nil },
            progress: { _, _ in },
            completion: completion
        )
    }

    /// Top‑level backup API: unmount → dd → mount
    static func backup(device: Device,
                       to url: URL,
                       progress: @escaping (Double, String) -> Void,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        var lastError: Error?

        // Step 1: Unmount
        unmount(device: device) { result in
            if case .failure(let error) = result {
                lastError = error
            }
            guard lastError == nil else {
                return completion(.failure(lastError!))
            }

            // Step 2: Perform dd backup
            performDDBackup(device: device, to: url, progress: progress) { result in
                if case .failure(let error) = result {
                    lastError = error
                }

                // Step 3: Remount (fire-and-forget errors)
                mount(device: device) { _ in
                    // Finally report final outcome
                    if let error = lastError {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }
}
