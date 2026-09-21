import SwiftUI

struct StorageView: View {
    @AppStorage("ixak.language") private var language: AppLanguage = .ru
    @State private var items: [LargeFileItem] = []
    @State private var isScanning = false
    @State private var showConfirm = false
    @State private var lastResult: BilingualText?

    private var totalSelectedBytes: Int64 {
        items.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        VStack {
            List {
                ForEach($items) { $item in
                    Toggle(isOn: $item.isSelected) {
                        HStack {
                            Text(item.url.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(item.sizeFormatted).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if items.isEmpty && !isScanning {
                BilingualLabel(en: "No files over 200 MB found yet — tap Scan", ru: "Файлов крупнее 200 МБ пока не найдено — нажмите «Сканировать»")
                    .foregroundStyle(.secondary)
                    .padding()
            }

            if let lastResult {
                BilingualLabel(lastResult).padding(.bottom, 4)
            }

            HStack {
                Button {
                    scan()
                } label: {
                    BilingualLabel(en: "Scan Home Folder", ru: "Сканировать домашнюю папку")
                }
                .disabled(isScanning)
                if isScanning { ProgressView() }
                Spacer()
                BilingualLabel(
                    en: "Selected: \(ByteCountFormatter.string(fromByteCount: totalSelectedBytes, countStyle: .file))",
                    ru: "Выбрано: \(ByteCountFormatter.string(fromByteCount: totalSelectedBytes, countStyle: .file))"
                )
                Button {
                    showConfirm = true
                } label: {
                    BilingualLabel(en: "Move Selected to Trash", ru: "Переместить выбранное в корзину")
                }
                .disabled(totalSelectedBytes == 0)
            }
            .padding()
        }
        .alert(language == .en ? "Move to Trash?" : "Переместить в корзину?", isPresented: $showConfirm) {
            Button(language == .en ? "Cancel" : "Отмена", role: .cancel) {}
            Button(language == .en ? "Move" : "Переместить", role: .destructive) { performCleanup() }
        } message: {
            Text(language == .en ? "Apps and bundles are moved whole — nothing is deleted from inside a working app." : "Приложения и бандлы перемещаются целиком — файлы внутри рабочего приложения не трогаются.")
        }
    }

    private func scan(clearResult: Bool = true) {
        isScanning = true
        if clearResult { lastResult = nil }
        Task {
            let result = await Task.detached { StorageScanner.scan() }.value
            await MainActor.run {
                items = result
                isScanning = false
            }
        }
    }

    private func performCleanup() {
        let selected = items.filter(\.isSelected)
        Task {
            let failures = await Task.detached { StorageScanner.moveToTrash(selected) }.value
            await MainActor.run {
                lastResult = failures.isEmpty
                    ? BilingualText(en: "Moved \(selected.count) items to Trash", ru: "Перемещено \(selected.count) объектов в корзину")
                    : BilingualText(en: "\(failures.count) items failed: \(failureReason(failures))", ru: "Не удалось переместить: \(failures.count) (\(failureReason(failures)))")
                scan(clearResult: false)
            }
        }
    }

    private func failureReason(_ failures: [URL: Error]) -> String {
        failures.values.first?.localizedDescription ?? "?"
    }
}

#Preview {
    StorageView()
}
