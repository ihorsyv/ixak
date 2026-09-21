import Foundation

struct InstalledApp: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let bundleID: String?
    let sizeBytes: Int64

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

struct LeftoverItem: Identifiable {
    let id = UUID()
    let url: URL
    let sizeBytes: Int64
    var isSelected: Bool = true

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Finds installed .app bundles and, given one, the files it scatters
/// across ~/Library — and separately, files that look like app leftovers
/// but whose owning app isn't installed anywhere IXAK can see: leftovers
/// from a past uninstall that only dragged the .app to Trash.
enum UninstallerScanner {
    private static func leftoverDirectories() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Preferences"),
            home.appendingPathComponent("Library/Saved Application State"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Containers"),
            home.appendingPathComponent("Library/WebKit"),
            home.appendingPathComponent("Library/HTTPStorages"),
        ]
    }

    private static func appDirectories() -> [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
    }

    static func installedApps() -> [InstalledApp] {
        let fm = FileManager.default
        var apps: [InstalledApp] = []
        for dir in appDirectories() {
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for url in entries where url.pathExtension == "app" {
                let bundleID = Bundle(url: url)?.bundleIdentifier
                let name = fm.displayName(atPath: url.path)
                let size = FileSizeUtil.directorySize(at: url) ?? 0
                apps.append(InstalledApp(url: url, name: name, bundleID: bundleID, sizeBytes: size))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Entries under the leftover directories whose name references the
    /// app's bundle identifier or display name.
    static func leftovers(for app: InstalledApp) -> [LeftoverItem] {
        let needles = [app.bundleID, app.name].compactMap { $0?.lowercased() }.filter { !$0.isEmpty }
        guard !needles.isEmpty else { return [] }

        return scanLeftoverDirectories { stemLower in
            needles.contains { stemLower.contains($0) }
        }
    }

    /// Entries that look like a reverse-DNS bundle identifier (the naming
    /// convention macOS itself uses for these files) but don't match any
    /// currently installed app.
    ///
    /// Two safety filters beyond the exact-ID check:
    /// - com.apple.* is always excluded. Most of it is background daemons
    ///   (com.apple.homed, com.apple.remindd, ...) that never appear as a
    ///   .app in /Applications yet are very much alive — flagging their
    ///   caches/state as "orphaned" would be actively misleading.
    /// - A vendor-prefix match (first two dotted components, e.g.
    ///   "com.microsoft") also counts as installed, since helper processes
    ///   often write under a sibling ID to the app's own bundle ID (e.g.
    ///   "com.microsoft.autoupdate.fba" next to the app's
    ///   "com.microsoft.autoupdate2") — an exact-ID match alone would flag
    ///   live helper data from an app that's still installed.
    static func orphanedLeftovers() -> [LeftoverItem] {
        let installedIDs = Set(installedApps().compactMap { $0.bundleID?.lowercased() })
        let installedVendorPrefixes = Set(installedIDs.compactMap(vendorPrefix))
        guard let bundleIDPattern = try? NSRegularExpression(pattern: #"^[a-z0-9]+(\.[a-z0-9-]+){2,}$"#) else { return [] }

        return scanLeftoverDirectories { stemLower in
            guard !stemLower.hasPrefix("com.apple.") else { return false }
            let range = NSRange(stemLower.startIndex..., in: stemLower)
            guard bundleIDPattern.firstMatch(in: stemLower, range: range) != nil else { return false }
            if installedIDs.contains(stemLower) { return false }
            if let prefix = vendorPrefix(of: stemLower), installedVendorPrefixes.contains(prefix) { return false }
            return true
        }
    }

    private static func vendorPrefix(of bundleID: String) -> String? {
        let parts = bundleID.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        return "\(parts[0]).\(parts[1])"
    }

    private static func scanLeftoverDirectories(matching predicate: (String) -> Bool) -> [LeftoverItem] {
        let fm = FileManager.default
        var results: [LeftoverItem] = []
        var seenPaths = Set<String>()

        for dir in leftoverDirectories() {
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for url in entries {
                let stemLower = url.deletingPathExtension().lastPathComponent.lowercased()
                guard predicate(stemLower), seenPaths.insert(url.path).inserted else { continue }
                let size = FileSizeUtil.directorySize(at: url) ?? 0
                results.append(LeftoverItem(url: url, sizeBytes: size))
            }
        }
        return results.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    static func moveToTrash(_ items: [LeftoverItem]) -> [URL: Error] {
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

    static func moveAppToTrash(_ app: InstalledApp) throws {
        try FileManager.default.trashItem(at: app.url, resultingItemURL: nil)
    }
}
