import SwiftUI

@main
struct IXAKApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .frame(minWidth: 640, minHeight: 480)
        }
        .windowResizability(.contentSize)
    }
}
