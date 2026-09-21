import SwiftUI

private enum UninstallMode: String, CaseIterable, Identifiable {
    case app = "By App / По приложению"
    case orphaned = "Orphaned Leftovers / Осиротевшие файлы"
    var id: String { rawValue }
}

struct UninstallView: View {
    @State private var mode: UninstallMode = .app

    @State private var apps: [InstalledApp] = []
    @State private var selectedApp: InstalledApp?
    @State private var leftovers: [LeftoverItem] = []
    @State private var isScanningLeftovers = false

    @State private var orphaned: [LeftoverItem] = []
    @State private var isScanningOrphaned = false

    @State private var showConfirm = false
    @State private var lastResult: String?

    var body: some View {
        VStack {
            Picker("", selection: $mode) {
                ForEach(UninstallMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top])

            if mode == .app {
                appModeBody
            } else {
                orphanedModeBody
            }

            if let lastResult {
                Text(lastResult).padding(.bottom, 4)
            }
        }
        .onAppear { if apps.isEmpty { loadApps() } }
        .alert("Move to Trash? / Переместить в корзину?", isPresented: $showConfirm) {
            Button("Cancel / Отмена", role: .cancel) {}
            Button("Move / Переместить", role: .destructive) { performTrash() }
        } message: {
            Text("Items go to Trash, not permanent deletion. / Файлы перемещаются в корзину, не удаляются безвозвратно.")
        }
    }

    private var appModeBody: some View {
        HSplitView {
            List(apps) { app in
                HStack {
                    Text(app.name)
                    Spacer()
                    Text(app.sizeFormatted).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .background(selectedApp?.id == app.id ? Color.accentColor.opacity(0.15) : Color.clear)
                .onTapGesture { selectApp(app) }
            }
            .frame(minWidth: 220)

            Group {
                if let selectedApp {
                    VStack {
                        List {
                            Section("Leftovers for \(selectedApp.name) / Хвосты \(selectedApp.name)") {
                                ForEach($leftovers) { $item in
                                    Toggle(isOn: $item.isSelected) {
                                        HStack {
                                            Text(item.url.path).lineLimit(1).truncationMode(.middle)
                                            Spacer()
                                            Text(item.sizeFormatted).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        if isScanningLeftovers { ProgressView() }
                        if leftovers.isEmpty && !isScanningLeftovers {
                            Text("No leftovers found / Хвосты не найдены")
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                        HStack {
                            Spacer()
                            Button("Trash App + Selected Leftovers / Удалить приложение и выбранные хвосты") {
                                showConfirm = true
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("Select an app on the left / Выберите приложение слева")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300)
        }
    }

    private var orphanedModeBody: some View {
        VStack {
            List {
                ForEach($orphaned) { $item in
                    Toggle(isOn: $item.isSelected) {
                        HStack {
                            Text(item.url.path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(item.sizeFormatted).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if orphaned.isEmpty && !isScanningOrphaned {
                Text("No orphaned leftovers found yet — tap Scan / Осиротевшие файлы пока не найдены — нажмите «Найти»")
                    .foregroundStyle(.secondary)
                    .padding()
            }

            HStack {
                Button("Scan for Orphaned Leftovers / Найти осиротевшие файлы") { scanOrphaned() }
                    .disabled(isScanningOrphaned)
                if isScanningOrphaned { ProgressView() }
                Spacer()
                Button("Move Selected to Trash / Переместить выбранное в корзину") {
                    showConfirm = true
                }
                .disabled(!orphaned.contains { $0.isSelected })
            }
            .padding()
        }
    }

    private func loadApps() {
        Task {
            let result = await Task.detached { UninstallerScanner.installedApps() }.value
            await MainActor.run { apps = result }
        }
    }

    private func selectApp(_ app: InstalledApp) {
        selectedApp = app
        leftovers = []
        isScanningLeftovers = true
        Task {
            let result = await Task.detached { UninstallerScanner.leftovers(for: app) }.value
            await MainActor.run {
                leftovers = result
                isScanningLeftovers = false
            }
        }
    }

    private func scanOrphaned() {
        isScanningOrphaned = true
        lastResult = nil
        Task {
            let result = await Task.detached { UninstallerScanner.orphanedLeftovers() }.value
            await MainActor.run {
                orphaned = result
                isScanningOrphaned = false
            }
        }
    }

    private func performTrash() {
        switch mode {
        case .app:
            guard let app = selectedApp else { return }
            let selectedLeftovers = leftovers.filter(\.isSelected)
            Task {
                var failureCount = 0
                do {
                    try await Task.detached { try UninstallerScanner.moveAppToTrash(app) }.value
                } catch {
                    failureCount += 1
                }
                let failures = await Task.detached { UninstallerScanner.moveToTrash(selectedLeftovers) }.value
                let totalFailures = failureCount + failures.count
                await MainActor.run {
                    lastResult = totalFailures == 0
                        ? "Removed \(app.name) and \(selectedLeftovers.count) leftovers / Удалено \(app.name) и \(selectedLeftovers.count) хвостов"
                        : "\(totalFailures) items failed / Не удалось удалить: \(totalFailures)"
                    selectedApp = nil
                    leftovers = []
                    loadApps()
                }
            }
        case .orphaned:
            let selected = orphaned.filter(\.isSelected)
            Task {
                let failures = await Task.detached { UninstallerScanner.moveToTrash(selected) }.value
                await MainActor.run {
                    if failures.isEmpty {
                        lastResult = "Moved \(selected.count) items to Trash / Перемещено \(selected.count) объектов в корзину"
                    } else {
                        lastResult = "\(failures.count) items failed / Не удалось переместить: \(failures.count)"
                    }
                    scanOrphaned()
                }
            }
        }
    }
}

#Preview {
    UninstallView()
}
