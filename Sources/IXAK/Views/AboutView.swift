import SwiftUI

struct AboutView: View {
    @State private var isChecking = false
    @State private var checkResult: UpdateCheckResult?
    @State private var isInstalling = false
    @State private var installError: BilingualText?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var builtCommit: String {
        Bundle.main.object(forInfoDictionaryKey: "IXAKGitCommit") as? String ?? "unknown"
    }

    var body: some View {
        Form {
            Section {
                BilingualLabel(
                    en: "IXAK is an offline macOS utility for hardware diagnostics, battery health, and safe cache cleanup.",
                    ru: "IXAK — офлайн-утилита для macOS: диагностика железа, здоровье батареи и безопасная чистка кэшей."
                )
                .fixedSize(horizontal: false, vertical: true)
                BilingualLabel(
                    en: "Built by ihorsyv for personal use only — not distributed or supported as a product.",
                    ru: "Сделано ihorsyv исключительно для личного использования — не распространяется и не поддерживается как продукт."
                )
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
            } header: {
                BilingualLabel(en: "About", ru: "О программе")
            }

            Section {
                LabeledContent {
                    Text(version)
                } label: {
                    BilingualLabel(en: "Version", ru: "Версия")
                }
                LabeledContent {
                    Text(builtCommit)
                } label: {
                    BilingualLabel(en: "Build commit", ru: "Коммит сборки")
                }
                Link(destination: URL(string: "https://github.com/ihorsyv/ixak")!) {
                    BilingualLabel(en: "View source on GitHub", ru: "Исходный код на GitHub")
                }
            } header: {
                BilingualLabel(en: "Version", ru: "Версия")
            }

            Section {
                Button {
                    checkForUpdates()
                } label: {
                    BilingualLabel(en: "Check for Updates", ru: "Проверить обновления")
                }
                .disabled(isChecking)

                if isChecking {
                    ProgressView()
                }

                if let checkResult {
                    switch checkResult {
                    case .upToDate:
                        BilingualLabel(en: "Up to date ✓", ru: "Установлена последняя версия ✓")
                            .foregroundStyle(.green)
                    case .updateAvailable(let sha, let pkgURL):
                        VStack(alignment: .leading, spacing: 4) {
                            BilingualLabel(en: "Update available (\(sha))", ru: "Доступно обновление (\(sha))")
                                .foregroundStyle(.orange)
                            Button {
                                installUpdate(from: pkgURL)
                            } label: {
                                BilingualLabel(en: "Install Update", ru: "Установить обновление")
                            }
                            .disabled(isInstalling)
                            if isInstalling {
                                ProgressView()
                            }
                            if let installError {
                                BilingualLabel(installError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    case .failed(let message):
                        BilingualLabel(en: "Check failed: \(message.en)", ru: "Проверка не удалась: \(message.ru)")
                            .foregroundStyle(.red)
                    }
                }
            } header: {
                BilingualLabel(en: "Updates", ru: "Обновления")
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
                    let message = error.localizedDescription
                    installError = BilingualText(en: message, ru: message)
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
