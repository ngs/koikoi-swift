import KoikoiUI
import SwiftUI

@main
struct KoikoiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        // Placeholder until KoikoiUI lands the real board.
        VStack(spacing: 12) {
            Text("こいこい")
                .font(.largeTitle)
            Text("Koikoi — coming soon")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
