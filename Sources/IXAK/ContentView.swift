import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        TabView {
            DiagnosticsView()
                .tabItem {
                    Label("Diagnostics\nДиагностика", systemImage: "waveform.path.ecg")
                }

            BatteryView()
                .tabItem {
                    Label("Battery\nБатарея", systemImage: "battery.100")
                }

            CleanupView()
                .tabItem {
                    Label("Cleanup\nЧистка", systemImage: "trash")
                }

            StorageView()
                .tabItem {
                    Label("Storage\nХранилище", systemImage: "internaldrive")
                }

            UninstallView()
                .tabItem {
                    Label("Uninstall\nУдаление", systemImage: "app.badge.checkmark")
                }

            AutostartView()
                .tabItem {
                    Label("Autostart\nАвтозапуск", systemImage: "power")
                }

            MaintenanceView()
                .tabItem {
                    Label("Maintenance\nОбслуживание", systemImage: "wrench.and.screwdriver")
                }

            AboutView()
                .tabItem {
                    Label("About\nО программе", systemImage: "info.circle")
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
