// BackupManager.swift
// Spawns `dd` to perform backup

import Foundation

class BackupManager {
    static func backup(device: Device, to url: URL,
                       progress: @escaping (Double, String) -> Void,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        let cmd = "/bin/dd"
        let args = ["if=\(device.identifier)", "of=\(url.path)", "bs=8m", "status=progress"]
        ShellRunner.run(cmd: cmd, args: args,
                        progressParser: DDProgressParser.parse,
                        progress: progress,
                        completion: completion)
    }
}
