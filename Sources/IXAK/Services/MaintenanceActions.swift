import Foundation

struct MaintenanceAction: Identifiable {
    let id = UUID()
    let title: BilingualText
    let description: BilingualText
    let run: () throws -> BilingualText
}

/// One-shot system maintenance commands — no scheduling, no background
/// timer, nothing runs until the user taps its button, same as every other
/// action in IXAK.
enum MaintenanceActions {
    static let all: [MaintenanceAction] = [
        MaintenanceAction(
            title: BilingualText(en: "Rebuild Spotlight Index", ru: "Пересоздать индекс Spotlight"),
            description: BilingualText(en: "Fixes broken search results by forcing a full re-index.", ru: "Чинит поиск, запуская полную переиндексацию."),
            run: { try runPrivileged("mdutil -E /") }
        ),
        MaintenanceAction(
            title: BilingualText(en: "Flush DNS Cache", ru: "Сбросить кэш DNS"),
            description: BilingualText(en: "Clears cached DNS lookups — helps after network/VPN changes.", ru: "Очищает кэш DNS-запросов — помогает после смены сети/VPN."),
            run: { try runPrivileged("dscacheutil -flushcache; killall -HUP mDNSResponder") }
        ),
        MaintenanceAction(
            title: BilingualText(en: "Purge Inactive Memory", ru: "Освободить неактивную память"),
            description: BilingualText(en: "Forces macOS to release cached (inactive) RAM back to free memory.", ru: "Заставляет macOS освободить кэшированную (неактивную) память."),
            run: { try runPrivileged("purge") }
        ),
        MaintenanceAction(
            title: BilingualText(en: "Rebuild Font Cache", ru: "Пересоздать кэш шрифтов"),
            description: BilingualText(en: "Clears and restarts the font-matching service — fixes garbled or missing fonts.", ru: "Очищает и перезапускает сервис подбора шрифтов."),
            run: {
                _ = try run("/usr/bin/atsutil", ["databases", "-removeUser"])
                _ = try run("/usr/bin/atsutil", ["server", "-shutdown"])
                _ = try run("/usr/bin/atsutil", ["server", "-ping"])
                return BilingualText(en: "Done", ru: "Готово")
            }
        ),
    ]

    @discardableResult
    private static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "IXAK.Maintenance",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Command failed" : output]
            )
        }
        return output
    }

    /// Routes the command through the standard macOS admin-password prompt
    /// (osascript's "with administrator privileges") rather than IXAK
    /// itself running with elevated rights.
    private static func runPrivileged(_ shellCommand: String) throws -> BilingualText {
        let escaped = shellCommand.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let output = try run("/usr/bin/osascript", ["-e", script])
        guard !output.isEmpty else { return BilingualText(en: "Done", ru: "Готово") }
        // Raw command output — not IXAK's own text, so there's no Russian
        // translation to give it; shown as-is on both lines.
        return BilingualText(en: output, ru: output)
    }
}
