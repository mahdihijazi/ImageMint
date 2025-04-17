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
        // TODO: Use DiskArbitration or `diskutil list -plist` via Helpers.runShell
        // Parse output and publish Device list
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
