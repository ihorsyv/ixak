import Foundation

struct MaintenanceAction: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let run: () throws -> String
}

/// One-shot system maintenance commands — no scheduling, no background
/// timer, nothing runs until the user taps its button, same as every other
/// action in IXAK.
enum MaintenanceActions {
    static let all: [MaintenanceAction] = [
        MaintenanceAction(
            title: "Rebuild Spotlight Index / Пересоздать индекс Spotlight",
            description: "Fixes broken search results by forcing a full re-index. / Чинит поиск, запуская полную переиндексацию.",
            run: { try runPrivileged("mdutil -E /") }
        ),
        MaintenanceAction(
            title: "Flush DNS Cache / Сбросить кэш DNS",
            description: "Clears cached DNS lookups — helps after network/VPN changes. / Очищает кэш DNS-запросов — помогает после смены сети/VPN.",
            run: { try runPrivileged("dscacheutil -flushcache; killall -HUP mDNSResponder") }
        ),
        MaintenanceAction(
            title: "Purge Inactive Memory / Освободить неактивную память",
            description: "Forces macOS to release cached (inactive) RAM back to free memory. / Заставляет macOS освободить кэшированную (неактивную) память.",
            run: { try runPrivileged("purge") }
        ),
        MaintenanceAction(
            title: "Rebuild Font Cache / Пересоздать кэш шрифтов",
            description: "Clears and restarts the font-matching service — fixes garbled or missing fonts. / Очищает и перезапускает сервис подбора шрифтов.",
            run: {
                _ = try run("/usr/bin/atsutil", ["databases", "-removeUser"])
                _ = try run("/usr/bin/atsutil", ["server", "-shutdown"])
                _ = try run("/usr/bin/atsutil", ["server", "-ping"])
                return "Done / Готово"
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
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Command failed / Команда завершилась с ошибкой" : output]
            )
        }
        return output.isEmpty ? "Done / Готово" : output
    }

    /// Routes the command through the standard macOS admin-password prompt
    /// (osascript's "with administrator privileges") rather than IXAK
    /// itself running with elevated rights.
    private static func runPrivileged(_ shellCommand: String) throws -> String {
        let escaped = shellCommand.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return try run("/usr/bin/osascript", ["-e", script])
    }
}
