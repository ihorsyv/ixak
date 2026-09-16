import SwiftUI

@main
struct IXAKApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 480)
        }
        .windowResizability(.contentSize)
    }
}
