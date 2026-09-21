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

            StorageView()
                .tabItem {
                    Label("Storage / Хранилище", systemImage: "internaldrive")
                }

            UninstallView()
                .tabItem {
                    Label("Uninstall / Удаление", systemImage: "app.badge.checkmark")
                }

            AutostartView()
                .tabItem {
                    Label("Autostart / Автозапуск", systemImage: "power")
                }

            MaintenanceView()
                .tabItem {
                    Label("Maintenance / Обслуживание", systemImage: "wrench.and.screwdriver")
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
