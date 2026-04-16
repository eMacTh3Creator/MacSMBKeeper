import Foundation
import NetFS

enum SMBMountService {
    static func mount(share: SMBShare, password: String?) async throws {
        guard let smbURL = share.smbURL else {
            throw MountError.invalidURL
        }

        let mountDir = URL(fileURLWithPath: share.mountPoint, isDirectory: true)

        // Ensure mount directory exists
        if !FileManager.default.fileExists(atPath: share.mountPoint) {
            try FileManager.default.createDirectory(at: mountDir, withIntermediateDirectories: true)
        }

        // Build open options
        let openOptions = NSMutableDictionary()
        if !share.username.isEmpty {
            openOptions[kNAUIOptionKey] = kNAUIOptionNoUI
        }

        let mountOptions = NSMutableDictionary()
        mountOptions[kNetFSSoftMountKey] = true
        if !share.username.isEmpty {
            mountOptions[kNetFSMountAtMountDirKey] = true
        }

        let username: String? = share.username.isEmpty ? nil : share.username

        return try await withCheckedThrowingContinuation { continuation in
            let rc = NetFSMountURLSync(
                smbURL as CFURL,
                mountDir as CFURL,
                username as CFString?,
                password as CFString?,
                openOptions,
                mountOptions,
                nil
            )

            if rc == 0 {
                continuation.resume()
            } else {
                continuation.resume(throwing: MountError.mountFailed(rc))
            }
        }
    }

    static func unmount(share: SMBShare) throws {
        let expectedMount = URL(fileURLWithPath: share.mountPoint)
            .appendingPathComponent(share.shareName)
        let path = expectedMount.path

        guard FileManager.default.fileExists(atPath: path) else {
            return // Already unmounted
        }

        let result = Darwin.unmount(path, MNT_FORCE)
        if result != 0 {
            throw MountError.unmountFailed(errno)
        }
    }

    static func isMounted(share: SMBShare) -> Bool {
        let expectedPath = URL(fileURLWithPath: share.mountPoint)
            .appendingPathComponent(share.shareName)
            .path

        // Check if the path exists and is a mount point
        guard FileManager.default.fileExists(atPath: expectedPath) else {
            return false
        }

        // Verify it's actually an SMB mount by checking statfs
        var stat = statfs()
        guard statfs(expectedPath, &stat) == 0 else {
            return false
        }

        let fsType = withUnsafePointer(to: &stat.f_fstypename) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
                String(cString: $0)
            }
        }

        return fsType == "smbfs"
    }
}

enum MountError: LocalizedError {
    case invalidURL
    case mountFailed(Int32)
    case unmountFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid SMB URL"
        case .mountFailed(let code):
            "Mount failed with error code \(code)"
        case .unmountFailed(let code):
            "Unmount failed with error code \(code)"
        }
    }
}
