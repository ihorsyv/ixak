import SwiftUI

struct CleanupView: View {
    @State private var categories: [CleanupCategory] = []
    @State private var isScanning = false
    @State private var showConfirm = false
    @State private var lastResult: String?

    private var totalSelectedBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalSelectedBytes }
    }

    var body: some View {
        VStack {
            List {
                ForEach($categories) { $category in
                    Section(category.name) {
                        ForEach($category.items) { $item in
                            Toggle(isOn: $item.isSelected) {
                                HStack {
                                    Text(item.url.lastPathComponent)
                                    Spacer()
                                    Text(item.sizeFormatted).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if categories.isEmpty && !isScanning {
                Text("No items found in safe locations / В безопасных категориях ничего не найдено")
                    .foregroundStyle(.secondary)
                    .padding()
            }

            if let lastResult {
                Text(lastResult).padding(.bottom, 4)
            }

            HStack {
                Button("Scan / Сканировать") { scan() }
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
        .onAppear { scan() }
        .alert("Move to Trash? / Переместить в корзину?", isPresented: $showConfirm) {
            Button("Cancel / Отмена", role: .cancel) {}
            Button("Move / Переместить", role: .destructive) { performCleanup() }
        } message: {
            Text("Items go to Trash, not permanent deletion. / Файлы перемещаются в корзину, не удаляются безвозвратно.")
        }
    }

    private func scan() {
        isScanning = true
        lastResult = nil
        Task {
            let result = await Task.detached { CleanupScanner.scan() }.value
            await MainActor.run {
                categories = result
                isScanning = false
            }
        }
    }

    private func performCleanup() {
        let selected = categories.flatMap { $0.items.filter(\.isSelected) }
        Task {
            let failures = await Task.detached { CleanupScanner.moveToTrash(selected) }.value
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
    CleanupView()
}
