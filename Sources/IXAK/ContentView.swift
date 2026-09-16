import SwiftUI

struct ContentView: View {
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
        }
    }
}

#Preview {
    ContentView()
}
