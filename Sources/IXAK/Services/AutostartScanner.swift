import Foundation

struct AutostartItem: Identifiable {
    let id = UUID()
    let url: URL
    let label: String
    let scope: BilingualText
    var isSelected: Bool = false

    var isWritable: Bool {
        FileManager.default.isDeletableFile(atPath: url.path)
    }
}

/// Lists LaunchAgents/LaunchDaemons plists — the standard, publicly
/// documented autostart mechanism on macOS. Modern "Login Items" (System
/// Settings > General > Login Items) have no public enumeration API on
/// current macOS, so they're intentionally out of scope; LaunchAgents and
/// LaunchDaemons cover what tools like KnockKnock mainly surface anyway.
enum AutostartScanner {
    private static func locations() -> [(scope: BilingualText, url: URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            (BilingualText(en: "User", ru: "Пользователь"), home.appendingPathComponent("Library/LaunchAgents")),
            (BilingualText(en: "System", ru: "Система"), URL(fileURLWithPath: "/Library/LaunchAgents")),
            (BilingualText(en: "System", ru: "Система"), URL(fileURLWithPath: "/Library/LaunchDaemons")),
        ]
    }

    static func scan() -> [AutostartItem] {
        let fm = FileManager.default
        var items: [AutostartItem] = []
        for location in locations() {
            guard let entries = try? fm.contentsOfDirectory(
                at: location.url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in entries where url.pathExtension == "plist" {
                let label = label(at: url) ?? url.deletingPathExtension().lastPathComponent
                items.append(AutostartItem(url: url, label: label, scope: location.scope))
            }
        }
        return items.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private static func label(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist["Label"] as? String
    }

    /// Unloads the job (best-effort) and moves its plist to Trash. Only
    /// meant to be called for items where isWritable is true — system items
    /// under /Library fail visibly here (returned in `failures`) rather
    /// than being silently skipped.
    static func remove(_ items: [AutostartItem]) -> [URL: Error] {
        var failures: [URL: Error] = [:]
        for item in items {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", item.url.path]
            try? process.run()
            process.waitUntilExit()

            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            } catch {
                failures[item.url] = error
            }
        }
        return failures
    }
}
