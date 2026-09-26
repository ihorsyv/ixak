import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage("ixak.language") private var language: AppLanguage = .ru
    @StateObject private var diagnostics = DiagnosticsModel()

    var body: some View {
        TabView {
            ThisMacView()
                .tabItem {
                    Label(language == .en ? "This Mac" : "Этот Mac", systemImage: "laptopcomputer")
                }

            DiagnosticsView(model: diagnostics)
                .tabItem {
                    Label(language == .en ? "Diagnostics" : "Диагностика", systemImage: "waveform.path.ecg")
                }

            BatteryView()
                .tabItem {
                    Label(language == .en ? "Battery" : "Батарея", systemImage: "battery.100")
                }

            CleanupView()
                .tabItem {
                    Label(language == .en ? "Cleanup" : "Чистка", systemImage: "trash")
                }

            StorageView()
                .tabItem {
                    Label(language == .en ? "Storage" : "Хранилище", systemImage: "internaldrive")
                }

            UninstallView()
                .tabItem {
                    Label(language == .en ? "Uninstall" : "Удаление", systemImage: "app.badge.checkmark")
                }

            AutostartView()
                .tabItem {
                    Label(language == .en ? "Autostart" : "Автозапуск", systemImage: "power")
                }

            MaintenanceView()
                .tabItem {
                    Label(language == .en ? "Maintenance" : "Обслуживание", systemImage: "wrench.and.screwdriver")
                }

            AboutView()
                .tabItem {
                    Label(language == .en ? "About" : "О программе", systemImage: "info.circle")
                }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.shortName).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 90)
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
