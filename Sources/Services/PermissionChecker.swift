import AppKit
import Foundation
import Security
import os

@MainActor
final class PermissionChecker: ObservableObject {
    enum Status: Sendable {
        case granted
        case denied
        case unknown

        var label: String {
            switch self {
            case .granted: "Granted"
            case .denied: "Not Granted"
            case .unknown: "Checking..."
            }
        }
    }

    @Published var fullDiskAccess: Status = .unknown
    @Published var keychainAccess: Status = .unknown
    @Published var networkAccess: Status = .unknown

    private let logger = Logger(subsystem: "com.everettjenkins.MacSMBKeeper", category: "Permissions")

    func checkAll() {
        checkFullDiskAccess()
        checkKeychainAccess()
        checkNetworkAccess()
    }

    // MARK: - Full Disk Access

    func checkFullDiskAccess() {
        // Attempt to open a file that is ALWAYS TCC-gated by Full Disk Access.
        // Reading Library/Safari/Bookmarks.plist or TCC.db directly will succeed
        // only if FDA is granted. If the path doesn't exist, fall back to the
        // system-wide TCC.db which exists on every Mac.

        let tccGatedPaths: [String] = [
            NSHomeDirectory() + "/Library/Safari/Bookmarks.plist",
            NSHomeDirectory() + "/Library/Safari/CloudTabs.db",
            NSHomeDirectory() + "/Library/Messages/chat.db",
            NSHomeDirectory() + "/Library/Mail",
            NSHomeDirectory() + "/Library/Calendars",
            "/Library/Application Support/com.apple.TCC/TCC.db",
        ]

        let fm = FileManager.default

        // Try to actually open each file that exists. isReadableFile returns
        // true for paths that pass sandbox but not for TCC-denied files, which
        // is why we use open() as the definitive test.
        for path in tccGatedPaths {
            guard fm.fileExists(atPath: path) else { continue }

            let fd = open(path, O_RDONLY)
            if fd >= 0 {
                close(fd)
                fullDiskAccess = .granted
                logger.info("Full Disk Access: granted (verified via \(path))")
                return
            }
        }

        // No gated path was readable. FDA likely not granted. Note that
        // Mac SMB Keeper does not actually require FDA for SMB mounts —
        // this check is informational.
        fullDiskAccess = .denied
        logger.info("Full Disk Access: not granted (optional for SMB mounting)")
    }

    // MARK: - Keychain Access

    func checkKeychainAccess() {
        // Read-only query for a NON-EXISTENT item. This never prompts the user
        // because nothing needs to be unlocked or created. We look at the
        // return code:
        //   errSecItemNotFound -> Keychain API is reachable, access OK
        //   errSecInteractionNotAllowed / errSecAuthFailed -> access denied
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "MacSMBKeeper-ProbeNonExistent-\(UUID().uuidString)",
            kSecAttrAccount as String: "probe",
            kSecReturnAttributes as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecItemNotFound, errSecSuccess:
            keychainAccess = .granted
            logger.info("Keychain access: granted")
        case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
            keychainAccess = .denied
            logger.warning("Keychain access: denied (status \(status))")
        default:
            // Any other status (e.g., errSecMissingEntitlement) we treat as
            // accessible — these are errors that don't indicate the user
            // blocked us.
            keychainAccess = .granted
            logger.info("Keychain access: reachable (status \(status))")
        }
    }

    // MARK: - Network Access

    func checkNetworkAccess() {
        // A successful HTTPS request to any public host confirms basic outbound
        // network works. Local-network (Bonjour/mDNS) permission is separate;
        // it's prompted automatically on first use.
        Task {
            do {
                let url = URL(string: "https://api.github.com")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                let (_, response) = try await URLSession.shared.data(for: request)
                if response is HTTPURLResponse {
                    networkAccess = .granted
                    logger.info("Network access: granted")
                } else {
                    networkAccess = .granted
                }
            } catch {
                networkAccess = .denied
                logger.warning("Network access check failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Open System Settings

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openNetworkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openKeychainAccess() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Keychain Access.app"))
    }

    static func openSecuritySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}
