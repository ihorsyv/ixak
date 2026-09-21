import SwiftUI

struct AboutView: View {
    @State private var isChecking = false
    @State private var checkResult: UpdateCheckResult?
    @State private var isInstalling = false
    @State private var installError: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var builtCommit: String {
        Bundle.main.object(forInfoDictionaryKey: "IXAKGitCommit") as? String ?? "unknown"
    }

    var body: some View {
        Form {
            Section("About / О программе") {
                Text("IXAK is an offline macOS utility for hardware diagnostics, battery health, and safe cache cleanup.\nIXAK — офлайн-утилита для macOS: диагностика железа, здоровье батареи и безопасная чистка кэшей.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Built by ihorsyv for personal use only — not distributed or supported as a product.\nСделано ihorsyv исключительно для личного использования — не распространяется и не поддерживается как продукт.")
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            }

            Section("Version / Версия") {
                LabeledContent("Version / Версия", value: version)
                LabeledContent("Build commit / Коммит сборки", value: builtCommit)
                Link("View source on GitHub / Исходный код на GitHub",
                     destination: URL(string: "https://github.com/ihorsyv/ixak")!)
            }

            Section("Updates / Обновления") {
                Button("Check for Updates / Проверить обновления") {
                    checkForUpdates()
                }
                .disabled(isChecking)

                if isChecking {
                    ProgressView()
                }

                if let checkResult {
                    switch checkResult {
                    case .upToDate:
                        Text("Up to date / Установлена последняя версия ✓")
                            .foregroundStyle(.green)
                    case .updateAvailable(let sha, let pkgURL):
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Update available (\(sha)) / Доступно обновление (\(sha))")
                                .foregroundStyle(.orange)
                            Button("Install Update / Установить обновление") {
                                installUpdate(from: pkgURL)
                            }
                            .disabled(isInstalling)
                            if isInstalling {
                                ProgressView()
                            }
                            if let installError {
                                Text(installError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    case .failed(let message):
                        Text("Check failed / Проверка не удалась: \(message)")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func checkForUpdates() {
        isChecking = true
        checkResult = nil
        installError = nil
        Task {
            let result = await UpdateChecker.check()
            await MainActor.run {
                checkResult = result
                isChecking = false
            }
        }
    }

    private func installUpdate(from pkgURL: URL) {
        isInstalling = true
        installError = nil
        Task {
            do {
                try await UpdateChecker.downloadAndOpenInstaller(from: pkgURL)
            } catch {
                await MainActor.run {
                    installError = error.localizedDescription
                }
            }
            await MainActor.run {
                isInstalling = false
            }
        }
    }
}

#Preview {
    AboutView()
}
