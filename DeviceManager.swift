// DeviceManager.swift
// Discover devices and handle backup/restore requests

import Foundation
import Combine

struct Device: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let identifier: String
    let size: Int64

    var displayName: String {
        let gb = Double(size) / 1_000_000_000
        return String(format: "%@ (%.1f GB)", name, gb)
    }
}

class DeviceManager: ObservableObject {
    @Published var devices: [Device] = []
    @Published var progress: Double = 0.0
    @Published var statusText: String = "Ready"

    func refreshDevices() {
        print("refreshDevices() called!")

        devices = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["list", "-plist"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            print("diskutil launched successfully")
        } catch {
            print("Failed to run diskutil: \(error)")
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        print("diskutil returned \(data.count) bytes")

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any],
              let allDisks = dict["AllDisksAndPartitions"] as? [[String: Any]] else {
            print("Failed to parse diskutil output")
            return
        }

        var foundDevices: [Device] = []

        for disk in allDisks {
            // skip internal disks
            let isInternal = (disk["OSInternal"] as? Bool) ?? true
            if isInternal { continue }

            // if there are partitions, only pick ones mounted under /Volumes/
            if let partitions = disk["Partitions"] as? [[String: Any]] {
                for partition in partitions {
                    guard
                      let mountPoint = partition["MountPoint"] as? String,
                      mountPoint.hasPrefix("/Volumes/"),
                      let identifier = partition["DeviceIdentifier"] as? String,
                      let size = partition["Size"] as? Int64
                    else { continue }

                    let name = partition["VolumeName"] as? String ?? identifier
                    foundDevices.append(
                        Device(
                          name: "\(name)",
                          identifier: "/dev/rdisk\(identifier)",
                          size: size
                        )
                    )
                }
            }
            // (we skip disks with no mountable partitions)
        }

        print("Devices ready to display: \(foundDevices)")

        DispatchQueue.main.async {
            self.devices = foundDevices
        }
    }


    
    /// Handles file export (Backup) result from ContentView
    func handleBackup(device: Device?, result: Result<URL, Error>) {
        guard let device = device else {
            statusText = "No device selected"
            return
        }
        switch result {
        case .success(let url):
            BackupManager.backup(device: device, to: url,
                                 progress: updateProgress,
                                 completion: finishHandler)
        case .failure(let error):
            statusText = "Backup cancelled: \(error.localizedDescription)"
        }
    }

    /// Handles file import (Restore) result from ContentView
    func handleRestore(device: Device?, result: Result<URL, Error>) {
        guard let device = device else {
            statusText = "No device selected"
            return
        }
        switch result {
        case .success(let url):
            RestoreManager.restore(image: url, to: device,
                                   progress: updateProgress,
                                   completion: finishHandler)
        case .failure(let error):
            statusText = "Restore cancelled: \(error.localizedDescription)"
        }
    }

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
