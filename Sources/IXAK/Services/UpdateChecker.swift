import Foundation

enum UpdateCheckResult {
    case upToDate
    case updateAvailable(latestSHA: String)
    case failed(String)
}

/// Compares the commit baked into this build (see IXAKGitCommit in
/// Info.plist, set by Scripts/build_app.sh) against the latest commit on
/// the public repo's main branch. Only runs when the user taps the button
/// — no background polling, no telemetry, no account needed.
enum UpdateChecker {
    private static let apiURL = URL(string: "https://api.github.com/repos/ihorsyv/ixak/commits/main")!

    static func check() async -> UpdateCheckResult {
        guard let builtSHA = Bundle.main.object(forInfoDictionaryKey: "IXAKGitCommit") as? String,
              !builtSHA.isEmpty, builtSHA != "unknown" else {
            return .failed("Build commit not recorded / Коммит сборки не записан")
        }

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .failed("GitHub request failed / Запрос к GitHub не удался")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fullSHA = json["sha"] as? String else {
                return .failed("Unexpected response / Неожиданный ответ")
            }

            let latestShort = String(fullSHA.prefix(7))
            if latestShort == builtSHA {
                return .upToDate
            } else {
                return .updateAvailable(latestSHA: latestShort)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
