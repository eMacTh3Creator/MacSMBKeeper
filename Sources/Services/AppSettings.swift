import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet { updateLoginItem() }
    }

    @Published var checkForUpdates: Bool {
        didSet { UserDefaults.standard.set(checkForUpdates, forKey: "checkForUpdates") }
    }

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String = ""

    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
    static let githubRepo = "eMacTh3Creator/MacSMBKeeper"

    init() {
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.checkForUpdates = UserDefaults.standard.bool(forKey: "checkForUpdates")

        if checkForUpdates {
            Task { await checkForNewVersion() }
        }
    }

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert on failure
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func checkForNewVersion() async {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.githubRepo)/releases/latest") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String {
                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                latestVersion = version
                updateAvailable = isNewer(version, than: Self.currentVersion)
            }
        } catch {
            // Silently fail — non-critical
        }
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
