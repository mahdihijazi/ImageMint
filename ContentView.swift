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

            List(selection: $selectedDevice) {
                ForEach(deviceManager.devices) { device in
                    Text(device.displayName)
                }
            }
            .frame(minHeight: 200)

            HStack {
                Button("Backup…") {
                    showBackupPicker = true
                }
                .disabled(selectedDevice == nil)

                Button("Restore…") {
                    showRestorePicker = true
                }
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

// Empty placeholder document to satisfy fileExporter
struct BackupPlaceholderDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    init() { }

    init(configuration: ReadConfiguration) throws { }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: Data())
    }
}
