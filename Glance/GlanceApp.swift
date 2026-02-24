import SwiftUI

@main
struct GlanceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 300, height: 200)
        .windowResizability(.contentSize)
    }
}
