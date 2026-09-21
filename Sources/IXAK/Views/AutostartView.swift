import SwiftUI

struct AutostartView: View {
    @State private var items: [AutostartItem] = []
    @State private var isScanning = false
    @State private var showConfirm = false
    @State private var lastResult: String?

    private var selectedItems: [AutostartItem] {
        items.filter(\.isSelected)
    }

    var body: some View {
        VStack {
            Text("System-owned items are shown for awareness but can't be removed here. / Системные элементы показаны для информации, но не могут быть удалены отсюда.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            List {
                ForEach($items) { $item in
                    Toggle(isOn: $item.isSelected) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.label)
                                Text(item.url.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text(item.scope)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!item.isWritable)
                }
            }

            if items.isEmpty && !isScanning {
                Text("No LaunchAgents/LaunchDaemons found / LaunchAgents/LaunchDaemons не найдены")
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
                Button("Disable & Trash Selected / Отключить и переместить в корзину") {
                    showConfirm = true
                }
                .disabled(selectedItems.isEmpty)
            }
            .padding()
        }
        .onAppear { scan() }
        .alert("Disable and move to Trash? / Отключить и переместить в корзину?", isPresented: $showConfirm) {
            Button("Cancel / Отмена", role: .cancel) {}
            Button("Disable / Отключить", role: .destructive) { performRemoval() }
        } message: {
            Text("Unloads the job and moves its plist to Trash. / Выгружает задачу и перемещает её plist в корзину.")
        }
    }

    private func scan() {
        isScanning = true
        lastResult = nil
        Task {
            let result = await Task.detached { AutostartScanner.scan() }.value
            await MainActor.run {
                items = result
                isScanning = false
            }
        }
    }

    private func performRemoval() {
        let selected = selectedItems
        Task {
            let failures = await Task.detached { AutostartScanner.remove(selected) }.value
            await MainActor.run {
                if failures.isEmpty {
                    lastResult = "Removed \(selected.count) items / Удалено \(selected.count) объектов"
                } else {
                    lastResult = "\(failures.count) items failed / Не удалось удалить: \(failures.count)"
                }
                scan()
            }
        }
    }
}

#Preview {
    AutostartView()
}
