import SwiftUI

struct AutostartView: View {
    @AppStorage("ixak.language") private var language: AppLanguage = .ru
    @State private var items: [AutostartItem] = []
    @State private var isScanning = false
    @State private var showConfirm = false
    @State private var lastResult: BilingualText?

    private var selectedItems: [AutostartItem] {
        items.filter(\.isSelected)
    }

    var body: some View {
        VStack {
            BilingualLabel(en: "System-owned items are shown for awareness but can't be removed here.", ru: "Системные элементы показаны для информации, но не могут быть удалены отсюда.")
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
                            BilingualLabel(item.scope)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!item.isWritable)
                }
            }

            if items.isEmpty && !isScanning {
                BilingualLabel(en: "No LaunchAgents/LaunchDaemons found", ru: "LaunchAgents/LaunchDaemons не найдены")
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
                Button {
                    showConfirm = true
                } label: {
                    BilingualLabel(en: "Disable & Trash Selected", ru: "Отключить и переместить в корзину")
                }
                .disabled(selectedItems.isEmpty)
            }
            .padding()
        }
        .onAppear { scan() }
        .alert(language == .en ? "Disable and move to Trash?" : "Отключить и переместить в корзину?", isPresented: $showConfirm) {
            Button(language == .en ? "Cancel" : "Отмена", role: .cancel) {}
            Button(language == .en ? "Disable" : "Отключить", role: .destructive) { performRemoval() }
        } message: {
            Text(language == .en ? "Unloads the job and moves its plist to Trash." : "Выгружает задачу и перемещает её plist в корзину.")
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
                lastResult = failures.isEmpty
                    ? BilingualText(en: "Removed \(selected.count) items", ru: "Удалено \(selected.count) объектов")
                    : BilingualText(en: "\(failures.count) items failed", ru: "Не удалось удалить: \(failures.count)")
                scan()
            }
        }
    }
}

#Preview {
    AutostartView()
}
