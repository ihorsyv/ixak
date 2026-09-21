import Foundation

struct CleanupItem: Identifiable {
    let id = UUID()
    let url: URL
    let sizeBytes: Int64
    var isSelected: Bool = true

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

struct CleanupCategory: Identifiable {
    let id = UUID()
    let name: BilingualText
    let directory: URL
    var items: [CleanupItem]

    var totalSelectedBytes: Int64 {
        items.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }
}

/// Scans only well-known, safe-to-clear locations. Nothing outside these
/// directories is ever touched, and items are moved to Trash, not deleted
/// permanently, so every action is reversible.
enum CleanupScanner {
    static func safeCategories() -> [(name: BilingualText, url: URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            (BilingualText(en: "App Caches", ru: "Кэши приложений"), home.appendingPathComponent("Library/Caches")),
            (BilingualText(en: "Logs", ru: "Логи"), home.appendingPathComponent("Library/Logs")),
            (BilingualText(en: "Xcode DerivedData", ru: "Сборки Xcode"), home.appendingPathComponent("Library/Developer/Xcode/DerivedData")),
            (BilingualText(en: "iOS Device Support", ru: "Файлы устройств iOS"), home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")),
        ]
    }

    static func scan() -> [CleanupCategory] {
        safeCategories().compactMap { category in
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: category.url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                return nil
            }

            let items = entries.compactMap { url -> CleanupItem? in
                guard let size = FileSizeUtil.directorySize(at: url) else { return nil }
                return CleanupItem(url: url, sizeBytes: size)
            }.sorted { $0.sizeBytes > $1.sizeBytes }

            guard !items.isEmpty else { return nil }
            return CleanupCategory(name: category.name, directory: category.url, items: items)
        }
    }

    /// Moves the given items to Trash. Never permanently deletes.
    static func moveToTrash(_ items: [CleanupItem]) -> [URL: Error] {
        var failures: [URL: Error] = [:]
        for item in items {
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            } catch {
                failures[item.url] = error
            }
        }
        return failures
    }
}
