import SwiftUI

private enum UninstallMode: CaseIterable, Identifiable {
    case app
    case orphaned
    var id: Self { self }

    func title(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.app, .en): "By App"
        case (.app, .ru): "По приложению"
        case (.orphaned, .en): "Orphaned Leftovers"
        case (.orphaned, .ru): "Осиротевшие файлы"
        }
    }
}

struct UninstallView: View {
    @AppStorage("ixak.language") private var language: AppLanguage = .ru
    @State private var mode: UninstallMode = .app

    @State private var apps: [InstalledApp] = []
    @State private var selectedApp: InstalledApp?
    @State private var leftovers: [LeftoverItem] = []
    @State private var isScanningLeftovers = false

    @State private var orphaned: [LeftoverItem] = []
    @State private var isScanningOrphaned = false

    @State private var showConfirm = false
    @State private var lastResult: BilingualText?

    var body: some View {
        VStack {
            Picker("", selection: $mode) {
                ForEach(UninstallMode.allCases) { Text($0.title(for: language)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top])

            BilingualLabel(
                en: "Some leftovers live inside another app's sandboxed container — deleting those needs Full Disk Access for IXAK (System Settings → Privacy & Security → Full Disk Access).",
                ru: "Часть хвостов лежит в песочнице другого приложения — для их удаления нужен доступ Full Disk Access для IXAK (Настройки системы → Конфиденциальность и безопасность → Полный доступ к диску)."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)

            if mode == .app {
                appModeBody
            } else {
                orphanedModeBody
            }

            if let lastResult {
                BilingualLabel(lastResult).padding(.bottom, 4)
            }
        }
        .onAppear { if apps.isEmpty { loadApps() } }
        .alert(language == .en ? "Move to Trash?" : "Переместить в корзину?", isPresented: $showConfirm) {
            Button(language == .en ? "Cancel" : "Отмена", role: .cancel) {}
            Button(language == .en ? "Move" : "Переместить", role: .destructive) { performTrash() }
        } message: {
            Text(language == .en ? "Items go to Trash, not permanent deletion." : "Файлы перемещаются в корзину, не удаляются безвозвратно.")
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
                            Section {
                                ForEach($leftovers) { $item in
                                    Toggle(isOn: $item.isSelected) {
                                        HStack {
                                            Text(item.url.path).lineLimit(1).truncationMode(.middle)
                                            Spacer()
                                            Text(item.sizeFormatted).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } header: {
                                BilingualLabel(en: "Leftovers for \(selectedApp.name)", ru: "Хвосты \(selectedApp.name)")
                            }
                        }
                        if isScanningLeftovers { ProgressView() }
                        if leftovers.isEmpty && !isScanningLeftovers {
                            BilingualLabel(en: "No leftovers found", ru: "Хвосты не найдены")
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                        HStack {
                            Spacer()
                            Button {
                                showConfirm = true
                            } label: {
                                BilingualLabel(en: "Trash App + Selected Leftovers", ru: "Удалить приложение и выбранные хвосты")
                            }
                        }
                        .padding()
                    }
                } else {
                    BilingualLabel(en: "Select an app on the left", ru: "Выберите приложение слева")
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
                BilingualLabel(en: "No orphaned leftovers found yet — tap Scan", ru: "Осиротевшие файлы пока не найдены — нажмите «Найти»")
                    .foregroundStyle(.secondary)
                    .padding()
            }

            HStack {
                Button {
                    scanOrphaned()
                } label: {
                    BilingualLabel(en: "Scan for Orphaned Leftovers", ru: "Найти осиротевшие файлы")
                }
                .disabled(isScanningOrphaned)
                if isScanningOrphaned { ProgressView() }
                Spacer()
                Button {
                    showConfirm = true
                } label: {
                    BilingualLabel(en: "Move Selected to Trash", ru: "Переместить выбранное в корзину")
                }
                .disabled(!orphaned.contains { $0.isSelected })
            }
            .padding()
        }
    }

    private func failureReason(_ failures: [URL: Error]) -> String {
        failures.values.first?.localizedDescription ?? "?"
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

    private func scanOrphaned(clearResult: Bool = true) {
        isScanningOrphaned = true
        if clearResult { lastResult = nil }
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
                        ? BilingualText(en: "Removed \(app.name) and \(selectedLeftovers.count) leftovers", ru: "Удалено \(app.name) и \(selectedLeftovers.count) хвостов")
                        : BilingualText(en: "\(totalFailures) items failed: \(failureReason(failures))", ru: "Не удалось удалить: \(totalFailures) (\(failureReason(failures)))")
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
                    lastResult = failures.isEmpty
                        ? BilingualText(en: "Moved \(selected.count) items to Trash", ru: "Перемещено \(selected.count) объектов в корзину")
                        : BilingualText(en: "\(failures.count) items failed: \(failureReason(failures))", ru: "Не удалось переместить: \(failures.count) (\(failureReason(failures)))")
                    scanOrphaned(clearResult: false)
                }
            }
        }
    }
}

#Preview {
    UninstallView()
}
