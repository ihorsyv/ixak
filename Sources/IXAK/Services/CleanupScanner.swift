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
    let name: String
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
    static func safeCategories() -> [(name: String, url: URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ("App Caches / Кэши приложений", home.appendingPathComponent("Library/Caches")),
            ("Logs / Логи", home.appendingPathComponent("Library/Logs")),
            ("Xcode DerivedData / Сборки Xcode", home.appendingPathComponent("Library/Developer/Xcode/DerivedData")),
            ("iOS Device Support / Файлы устройств iOS", home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")),
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
                guard let size = directorySize(at: url) else { return nil }
                return CleanupItem(url: url, sizeBytes: size)
            }.sorted { $0.sizeBytes > $1.sizeBytes }

            guard !items.isEmpty else { return nil }
            return CleanupCategory(name: category.name, directory: category.url, items: items)
        }
    }

    private static func directorySize(at url: URL) -> Int64? {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }

        if !isDirectory.boolValue {
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
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
