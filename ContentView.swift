import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var deviceManager = DeviceManager()
    @State private var selectedDevice: Device? = nil
    @State private var showBackupPicker = false
    @State private var showRestorePicker = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("ImageMint")
                .font(.largeTitle)
                .padding(.top)

            // Native macOS list
            List(deviceManager.devices, selection: $selectedDevice) { device in
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                    Text(String(format: "%.1f GB",
                                Double(device.size) / 1_000_000_000))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .tag(device)
            }
            .listStyle(SidebarListStyle())
            .frame(minHeight: 200)

            HStack {
                Button("Backup…") { showBackupPicker = true }
                    .disabled(selectedDevice == nil)

                Button("Restore…") { showRestorePicker = true }
                    .disabled(selectedDevice == nil)
            }
            .padding(.vertical)

            ProgressView(value: deviceManager.progress)
                .padding(.vertical)

            Text(deviceManager.statusText)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .fileExporter(
            isPresented: $showBackupPicker,
            document: BackupPlaceholderDocument(),
            contentType: .data,
            defaultFilename: "backup.img"
        ) { result in
            deviceManager.handleBackup(device: selectedDevice, result: result)
        }
        .fileImporter(
            isPresented: $showRestorePicker,
            allowedContentTypes: [.data]
        ) { result in
            deviceManager.handleRestore(device: selectedDevice, result: result)
        }
        .onAppear {
            deviceManager.refreshDevices()
        }
    }
}

// Placeholder document for fileExporter
struct BackupPlaceholderDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}
