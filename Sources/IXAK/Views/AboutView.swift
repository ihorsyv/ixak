import SwiftUI

struct AboutView: View {
    @State private var isChecking = false
    @State private var checkResult: UpdateCheckResult?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var builtCommit: String {
        Bundle.main.object(forInfoDictionaryKey: "IXAKGitCommit") as? String ?? "unknown"
    }

    var body: some View {
        Form {
            Section("About / О программе") {
                Text("IXAK is an offline macOS utility for hardware diagnostics, battery health, and safe cache cleanup. / IXAK — офлайн-утилита для macOS: диагностика железа, здоровье батареи и безопасная чистка кэшей.")
                Text("Built by ihorsyv for personal use only — not distributed or supported as a product. / Сделано ihorsyv исключительно для личного использования — не распространяется и не поддерживается как продукт.")
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
                    case .updateAvailable(let sha):
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Update available (\(sha)) / Доступно обновление (\(sha))")
                                .foregroundStyle(.orange)
                            Text("Pull the latest source and rebuild: git pull && ./Scripts/build_app.sh release --universal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
        Task {
            let result = await UpdateChecker.check()
            await MainActor.run {
                checkResult = result
                isChecking = false
            }
        }
    }
}

#Preview {
    AboutView()
}
