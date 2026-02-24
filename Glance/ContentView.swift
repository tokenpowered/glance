import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Glance is installed")
                .font(.headline)
            Text("Select a Markdown file in Finder and press Space to preview.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
