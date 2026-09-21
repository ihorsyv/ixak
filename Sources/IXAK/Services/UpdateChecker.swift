import AppKit
import Foundation

enum UpdateCheckResult {
    case upToDate
    case updateAvailable(latestSHA: String, pkgURL: URL)
    case failed(String)
}

enum UpdateInstallError: LocalizedError {
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let message): message
        }
    }
}

/// Compares the commit baked into this build (see IXAKGitCommit in
/// Info.plist, set by Scripts/build_app.sh) against the latest GitHub
/// Release — published as build-<shortsha> by .github/workflows/release.yml
/// on every push to main. Only runs when the user taps a button — no
/// background polling, no telemetry, no account needed.
enum UpdateChecker {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/ihorsyv/ixak/releases/latest")!

    static func check() async -> UpdateCheckResult {
        guard let builtSHA = Bundle.main.object(forInfoDictionaryKey: "IXAKGitCommit") as? String,
              !builtSHA.isEmpty, builtSHA != "unknown" else {
            return .failed("Build commit not recorded / Коммит сборки не записан")
        }

        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .failed("GitHub request failed / Запрос к GitHub не удался")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let assets = json["assets"] as? [[String: Any]] else {
                return .failed("Unexpected response / Неожиданный ответ")
            }

            let latestSHA = tagName.hasPrefix("build-") ? String(tagName.dropFirst("build-".count)) : tagName
            if latestSHA == builtSHA {
                return .upToDate
            }

            guard let pkgAsset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".pkg") == true }),
                  let urlString = pkgAsset["browser_download_url"] as? String,
                  let pkgURL = URL(string: urlString) else {
                return .failed("Release has no .pkg asset / В релизе нет .pkg")
            }

            return .updateAvailable(latestSHA: latestSHA, pkgURL: pkgURL)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Downloads the .pkg to a temp file and hands it to the system
    /// Installer via NSWorkspace — same as double-clicking it in Finder.
    /// macOS itself prompts for the admin password; IXAK never runs
    /// anything with elevated privileges.
    static func downloadAndOpenInstaller(from url: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateInstallError.downloadFailed("Download failed / Загрузка не удалась")
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("IXAK Installer.pkg")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)

        await MainActor.run {
            NSWorkspace.shared.open(destination)
        }
    }
}
