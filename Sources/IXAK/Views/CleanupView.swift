import SwiftUI

struct CleanupView: View {
    @State private var categories: [CleanupCategory] = []
    @State private var isScanning = false
    @State private var showConfirm = false
    @State private var lastResult: BilingualText?

    private var totalSelectedBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalSelectedBytes }
    }

    var body: some View {
        VStack {
            List {
                ForEach($categories) { $category in
                    Section {
                        ForEach($category.items) { $item in
                            Toggle(isOn: $item.isSelected) {
                                HStack {
                                    Text(item.url.lastPathComponent)
                                    Spacer()
                                    Text(item.sizeFormatted).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        BilingualLabel(category.name)
                    }
                }
            }

            if categories.isEmpty && !isScanning {
                BilingualLabel(en: "No items found in safe locations", ru: "В безопасных категориях ничего не найдено")
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
                    BilingualLabel(en: "Scan", ru: "Сканировать")
                }
                .disabled(isScanning)
                if isScanning { ProgressView() }
                Spacer()
                BilingualLabel(
                    en: "Selected: \(ByteCountFormatter.string(fromByteCount: totalSelectedBytes, countStyle: .file))",
                    ru: "Выбрано: \(ByteCountFormatter.string(fromByteCount: totalSelectedBytes, countStyle: .file))",
                    alignment: .trailing
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
        .onAppear { scan() }
        .alert("Move to Trash?\nПереместить в корзину?", isPresented: $showConfirm) {
            Button("Cancel / Отмена", role: .cancel) {}
            Button("Move / Переместить", role: .destructive) { performCleanup() }
        } message: {
            Text("Items go to Trash, not permanent deletion.\nФайлы перемещаются в корзину, не удаляются безвозвратно.")
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
                lastResult = failures.isEmpty
                    ? BilingualText(en: "Moved \(selected.count) items to Trash", ru: "Перемещено \(selected.count) объектов в корзину")
                    : BilingualText(en: "\(failures.count) items failed", ru: "Не удалось переместить: \(failures.count)")
                scan()
            }
        }
    }
}

#Preview {
    CleanupView()
}
