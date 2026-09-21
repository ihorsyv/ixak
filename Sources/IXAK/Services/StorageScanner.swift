import Foundation

struct LargeFileItem: Identifiable {
    let id = UUID()
    let url: URL
    let sizeBytes: Int64
    var isSelected: Bool = false

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Walks the user's home directory for anything above a size threshold.
/// Packages (.app, .framework, .bundle, .kext, ...) are reported as a
/// single opaque item at their total size rather than descended into —
/// deleting one file out of a working app would break it, so the only
/// sane unit to offer for removal is the whole bundle.
enum StorageScanner {
    private static let maxResults = 300

    static func scan(minSizeBytes: Int64 = 200 * 1024 * 1024) -> [LargeFileItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        guard let enumerator = fm.enumerator(
            at: home,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [LargeFileItem] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey, .isPackageKey]) else { continue }

            if values.isDirectory == true {
                guard values.isPackage == true else { continue }
                if let size = FileSizeUtil.directorySize(at: url), size >= minSizeBytes {
                    results.append(LargeFileItem(url: url, sizeBytes: size))
                }
                continue
            }

            guard values.isRegularFile == true else { continue }
            let size = Int64(values.fileSize ?? 0)
            guard size >= minSizeBytes else { continue }
            results.append(LargeFileItem(url: url, sizeBytes: size))
        }

        return Array(results.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(maxResults))
    }

    static func moveToTrash(_ items: [LargeFileItem]) -> [URL: Error] {
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
