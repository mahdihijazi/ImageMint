// DeviceManager.swift
// Discover removable disks and handle backup/restore requests

import Foundation
import Combine

struct Device: Identifiable, Hashable {
    let id = UUID()
    let name: String           // Friendly name (MediaName or BSD id)
    let identifier: String     // Raw device path, e.g. /dev/rdisk4
    let size: Int64            // Total size in bytes

    var displayName: String {
        let gb = Double(size) / 1_000_000_000
        return String(format: "%@ (%.1f GB)", name, gb)
    }
}

class DeviceManager: ObservableObject {
    @Published var devices: [Device] = []
    @Published var progress: Double = 0.0
    @Published var statusText: String = "Ready"

    /// Refresh the list of removable devices
    func refreshDevices() {
        devices = []

        // 1. List all disks
        let list = Process()
        list.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        list.arguments = ["list", "-plist"]
        let listPipe = Pipe()
        list.standardOutput = listPipe

        do {
            try list.run()
        } catch {
            print("❌ diskutil list failed:", error)
            return
        }

        let raw = listPipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let plist = try? PropertyListSerialization.propertyList(from: raw, options: [], format: nil),
            let dict = plist as? [String:Any],
            let allDisks = dict["AllDisksAndPartitions"] as? [[String:Any]]
        else {
            print("❌ could not parse diskutil list output")
            return
        }

        var found: [Device] = []

        for disk in allDisks {
            // 2. Extract the parent disk ID & size
            guard
                let id   = disk["DeviceIdentifier"] as? String,
                let size = disk["Size"] as? Int64
            else { continue }

            let diskNode = "/dev/\(id)"   // for info
            let rawNode  = "/dev/r\(id)"  // for dd

            // 3. Only include removable media
            guard
                let info      = Self.fetchDiskInfo(for: diskNode),
                let removable = info["RemovableMedia"] as? Bool,
                removable == true
            else {
                continue
            }

            // 4. Use a friendly MediaName if available
            let friendly = info["MediaName"] as? String
            let displayName = friendly ?? id

            found.append(
                Device(name: displayName,
                       identifier: rawNode,
                       size: size)
            )
        }

        DispatchQueue.main.async {
            self.devices = found
        }
    }

    /// Run `diskutil info -plist /dev/diskX` and return the info dictionary
    private static func fetchDiskInfo(for diskNode: String) -> [String:Any]? {
        let info = Process()
        info.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        info.arguments = ["info", "-plist", diskNode]
        let pipe = Pipe()
        info.standardOutput = pipe

        do {
            try info.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String:Any]
        else {
            return nil
        }
        return dict
    }

    // MARK: – Backup / Restore Handlers

    func handleBackup(device: Device?, result: Result<URL, Error>) {
        guard let device = device else {
            statusText = "No device selected"
            return
        }
        switch result {
        case .success(let url):
            BackupManager.backup(
                device: device,
                to: url,
                progress: updateProgress,
                completion: finishHandler
            )
        case .failure(let error):
            statusText = "Backup cancelled: \(error.localizedDescription)"
        }
    }

    func handleRestore(device: Device?, result: Result<URL, Error>) {
        guard let device = device else {
            statusText = "No device selected"
            return
        }
        switch result {
        case .success(let url):
            RestoreManager.restore(
                image: url,
                to: device,
                progress: updateProgress,
                completion: finishHandler
            )
        case .failure(let error):
            statusText = "Restore cancelled: \(error.localizedDescription)"
        }
    }

    // MARK: – Progress Updates

    private func updateProgress(_ fraction: Double, status: String) {
        DispatchQueue.main.async {
            self.progress = fraction
            self.statusText = status
        }
    }

    private func finishHandler(_ result: Result<Void, Error>) {
        DispatchQueue.main.async {
            switch result {
            case .success:
                self.statusText = "Operation completed successfully"
            case .failure(let error):
                self.statusText = "Error: \(error.localizedDescription)"
            }
            self.progress = 0.0
        }
    }
}
