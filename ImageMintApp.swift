import SwiftUI

@main
struct ImageMintApp: App {
    var body: some Scene {
        WindowGroup {
            // Make the window background the standard system color
            ContentView()
                .background(Color(nsColor: .windowBackgroundColor))
        }
        // Optional: give your window a sidebar-style appearance
        .windowStyle(DefaultWindowStyle())
    }
}
