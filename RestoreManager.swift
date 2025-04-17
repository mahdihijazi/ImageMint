// RestoreManager.swift
// Spawns `dd` to perform restore

import Foundation

class RestoreManager {
    static func restore(image url: URL, to device: Device,
                        progress: @escaping (Double, String) -> Void,
                        completion: @escaping (Result<Void, Error>) -> Void) {
        let cmd = "/bin/dd"
        let args = ["if=\(url.path)", "of=\(device.identifier)", "bs=8m", "status=progress"]
        ShellRunner.run(cmd: cmd, args: args,
                        progressParser: DDProgressParser.parse,
                        progress: progress,
                        completion: completion)
    }
}
