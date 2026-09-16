import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        TabView {
            DiagnosticsView()
                .tabItem {
                    Label("Diagnostics / Диагностика", systemImage: "waveform.path.ecg")
                }

            BatteryView()
                .tabItem {
                    Label("Battery / Батарея", systemImage: "battery.100")
                }

            CleanupView()
                .tabItem {
                    Label("Cleanup / Чистка", systemImage: "trash")
                }

            AboutView()
                .tabItem {
                    Label("About / О программе", systemImage: "info.circle")
                }
        }
        .onAppear {
            WindowOpener.shared.action = { openWindow(id: "main") }
        }
    }
}

#Preview {
    ContentView()
}
