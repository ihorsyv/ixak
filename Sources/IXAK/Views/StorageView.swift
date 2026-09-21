import SwiftUI

struct StorageView: View {
    @State private var items: [LargeFileItem] = []
    @State private var isScanning = false
    @State private var showConfirm = false
    @State private var lastResult: String?

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
                Text("No files over 200 MB found yet — tap Scan / Файлов крупнее 200 МБ пока не найдено — нажмите «Сканировать»")
                    .foregroundStyle(.secondary)
                    .padding()
            }

            if let lastResult {
                Text(lastResult).padding(.bottom, 4)
            }

            HStack {
                Button("Scan Home Folder / Сканировать домашнюю папку") { scan() }
                    .disabled(isScanning)
                if isScanning { ProgressView() }
                Spacer()
                Text("Selected / Выбрано: \(ByteCountFormatter.string(fromByteCount: totalSelectedBytes, countStyle: .file))")
                Button("Move Selected to Trash / Переместить выбранное в корзину") {
                    showConfirm = true
                }
                .disabled(totalSelectedBytes == 0)
            }
            .padding()
        }
        .alert("Move to Trash? / Переместить в корзину?", isPresented: $showConfirm) {
            Button("Cancel / Отмена", role: .cancel) {}
            Button("Move / Переместить", role: .destructive) { performCleanup() }
        } message: {
            Text("Apps and bundles are moved whole — nothing is deleted from inside a working app. / Приложения и бандлы перемещаются целиком — файлы внутри рабочего приложения не трогаются.")
        }
    }

    private func scan() {
        isScanning = true
        lastResult = nil
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
                if failures.isEmpty {
                    lastResult = "Moved \(selected.count) items to Trash / Перемещено \(selected.count) объектов в корзину"
                } else {
                    lastResult = "\(failures.count) items failed / Не удалось переместить: \(failures.count)"
                }
                scan()
            }
        }
    }
}

#Preview {
    StorageView()
}
