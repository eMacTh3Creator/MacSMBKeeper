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
        // Try to read a protected directory that requires FDA
        // ~/Library/Mail is a common FDA-gated path
        let testPaths = [
            NSHomeDirectory() + "/Library/Mail",
            NSHomeDirectory() + "/Library/Safari",
            "/Library/Application Support/com.apple.TCC/TCC.db",
        ]

        for path in testPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                fullDiskAccess = .granted
                logger.info("Full Disk Access: granted")
                return
            }
        }

        // If none of the protected paths are readable, FDA is likely not granted
        // However, the app may work fine without it for SMB operations
        // Only mark as denied if /Volumes is also not writable
        let volumesWritable = FileManager.default.isWritableFile(atPath: "/Volumes")
        if volumesWritable {
            fullDiskAccess = .granted
            logger.info("Full Disk Access: /Volumes writable, sufficient for SMB mounting")
        } else {
            fullDiskAccess = .denied
            logger.warning("Full Disk Access: not granted, /Volumes not writable")
        }
    }

    // MARK: - Keychain Access

    func checkKeychainAccess() {
        let testAccount = "com.everettjenkins.MacSMBKeeper.permissionCheck"
        let testData = "test".data(using: .utf8)!

        // Try to write a test item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "MacSMBKeeper-PermCheck",
            kSecAttrAccount as String: testAccount,
            kSecValueData as String: testData,
        ]

        // Clean up any previous test item
        SecItemDelete(addQuery as CFDictionary)

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus == errSecSuccess {
            // Clean up
            SecItemDelete(addQuery as CFDictionary)
            keychainAccess = .granted
            logger.info("Keychain access: granted")
        } else if addStatus == errSecInteractionNotAllowed {
            keychainAccess = .denied
            logger.warning("Keychain access: interaction not allowed (status \(addStatus))")
        } else if addStatus == errSecAuthFailed {
            keychainAccess = .denied
            logger.warning("Keychain access: auth failed (status \(addStatus))")
        } else {
            // Other errors may still be OK (e.g., duplicate item means we have access)
            keychainAccess = addStatus == errSecDuplicateItem ? .granted : .denied
            logger.info("Keychain access check status: \(addStatus)")
        }
    }

    // MARK: - Network Access

    func checkNetworkAccess() {
        // Check if we can create a socket connection (basic network test)
        // The local network permission prompt triggers on first network activity
        Task {
            do {
                let url = URL(string: "https://api.github.com")!
                let (_, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 403 {
                    networkAccess = .granted
                    logger.info("Network access: granted")
                } else {
                    networkAccess = .granted // Any response means network works
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
