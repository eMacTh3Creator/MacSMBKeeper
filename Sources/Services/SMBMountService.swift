import Foundation
import NetFS

enum SMBMountService {
    static func mount(share: SMBShare, password: String?) async throws {
        guard let smbURL = share.smbURL else {
            throw MountError.invalidURL
        }

        // 1. Already mounted at the expected path? Done.
        let expectedPath = URL(fileURLWithPath: share.mountPoint)
            .appendingPathComponent(share.shareName)
            .path
        if isMountedAtPath(expectedPath, scheme: "smbfs") {
            return
        }

        // 2. Already mounted at a DIFFERENT path by Finder / autofs / Bonjour?
        //    (e.g. /Volumes/CLOUD-1 instead of /Volumes/CLOUD). Treat as done.
        if existingSMBMountPath(forShare: share.shareName) != nil {
            return
        }

        // 3. Ensure the parent directory exists.
        let parentDir = URL(fileURLWithPath: share.mountPoint, isDirectory: true)
        if !FileManager.default.fileExists(atPath: share.mountPoint) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // 4. Clean up a stale placeholder at expectedPath if present.
        //    0111-mode stubs from a prior mount_smbfs can't be listed with
        //    contentsOfDirectory, but rmdir(2) works because they're empty.
        //    If rmdir fails, fall back to a unique path so we don't hit EEXIST.
        var targetPath = expectedPath
        if FileManager.default.fileExists(atPath: targetPath),
           !isMountedAtPath(targetPath, scheme: "smbfs") {
            if rmdir(targetPath) != 0 {
                let suffix = String(share.id.uuidString.prefix(8))
                targetPath = parentDir.appendingPathComponent("\(share.shareName)-\(suffix)").path
            }
        }

        // 5. Create the target directory and tell NetFS to mount AT it.
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: targetPath, isDirectory: true),
            withIntermediateDirectories: true
        )

        let openOptions = NSMutableDictionary()
        openOptions[kNAUIOptionKey] = kNAUIOptionNoUI

        let mountOptions = NSMutableDictionary()
        mountOptions[kNetFSSoftMountKey] = true
        mountOptions[kNetFSMountAtMountDirKey] = true

        let mountTarget = URL(fileURLWithPath: targetPath, isDirectory: true)
        let username: String? = share.username.isEmpty ? nil : share.username

        return try await withCheckedThrowingContinuation { continuation in
            let rc = NetFSMountURLSync(
                smbURL as CFURL,
                mountTarget as CFURL,
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

    /// Scan the kernel mount table for an smbfs mount whose remote share name
    /// matches `shareName`. Handles the case where Finder/autofs has already
    /// mounted the same share at a path other than `/Volumes/<shareName>`.
    private static func existingSMBMountPath(forShare shareName: String) -> String? {
        var mntsPtr: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&mntsPtr, MNT_NOWAIT)
        guard count > 0, let mnts = mntsPtr else { return nil }

        for i in 0..<Int(count) {
            var entry = mnts[i]

            let fsType = withUnsafePointer(to: &entry.f_fstypename) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
                    String(cString: $0)
                }
            }
            guard fsType == "smbfs" else { continue }

            let fromName = withUnsafePointer(to: &entry.f_mntfromname) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                    String(cString: $0)
                }
            }
            // f_mntfromname looks like "//user@host/SHARE"
            if let slash = fromName.lastIndex(of: "/") {
                let remoteShare = String(fromName[fromName.index(after: slash)...])
                if remoteShare.caseInsensitiveCompare(shareName) == .orderedSame {
                    let onName = withUnsafePointer(to: &entry.f_mntonname) {
                        $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                            String(cString: $0)
                        }
                    }
                    return onName
                }
            }
        }
        return nil
    }

    static func unmount(share: SMBShare) throws {
        let expectedMount = URL(fileURLWithPath: share.mountPoint)
            .appendingPathComponent(share.shareName)
        let path = expectedMount.path

        guard FileManager.default.fileExists(atPath: path) else {
            return // Already unmounted
        }

        // Verify it's actually a mount point before trying to unmount
        guard isMountedAtPath(path, scheme: "smbfs") else {
            return // Not an SMB mount, don't try to unmount
        }

        // Prefer diskutil over the raw unmount(2) syscall. Raw unmount returns
        // EPERM (error 1) when the mount wasn't made by the current process,
        // even when the user has Full Disk Access. diskutil talks to diskarbitrationd,
        // which performs the unmount on behalf of any user who owns the mount.
        if runDiskutilUnmount(path: path, force: false) {
            return
        }

        // Fall back to diskutil --force, which handles in-use files.
        if runDiskutilUnmount(path: path, force: true) {
            return
        }

        // Last resort: raw syscall. This rarely succeeds where diskutil failed,
        // but preserves previous behavior as a safety net.
        var result = Darwin.unmount(path, 0)
        if result == 0 { return }
        let gracefulError = errno
        result = Darwin.unmount(path, MNT_FORCE)
        if result == 0 { return }

        throw MountError.unmountFailed(gracefulError)
    }

    private static func runDiskutilUnmount(path: String, force: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        var args = ["unmount"]
        if force { args.append("force") }
        args.append(path)
        process.arguments = args

        // Discard output; we only care about the exit code.
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func isMounted(share: SMBShare) -> Bool {
        let expectedPath = URL(fileURLWithPath: share.mountPoint)
            .appendingPathComponent(share.shareName)
            .path
        return isMountedAtPath(expectedPath, scheme: "smbfs")
    }

    private static func isMountedAtPath(_ path: String, scheme: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }

        var stat = statfs()
        guard statfs(path, &stat) == 0 else {
            return false
        }

        let fsType = withUnsafePointer(to: &stat.f_fstypename) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
                String(cString: $0)
            }
        }

        return fsType == scheme
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
            "Mount failed (error \(code)): \(Self.describeMountError(code))"
        case .unmountFailed(let code):
            "Unmount failed (error \(code)): \(Self.describeUnmountError(code))"
        }
    }

    private static func describeMountError(_ code: Int32) -> String {
        switch code {
        case 2: return "Mount point not found (ENOENT)"
        case 13: return "Permission denied — check credentials (EACCES)"
        case 17: return "Already mounted or path in use (EEXIST)"
        case 22: return "Invalid SMB URL or argument (EINVAL)"
        case 51: return "Network unreachable (ENETUNREACH)"
        case 60: return "Connection timed out (ETIMEDOUT)"
        case 61: return "Connection refused — check SMB is enabled (ECONNREFUSED)"
        case 64: return "Host is down (EHOSTDOWN)"
        case 65: return "No route to host (EHOSTUNREACH)"
        default: return String(cString: strerror(code))
        }
    }

    private static func describeUnmountError(_ code: Int32) -> String {
        switch code {
        case 1: return "Operation not permitted — files may be in use (EPERM)"
        case 16: return "Device busy — close open files first (EBUSY)"
        default: return String(cString: strerror(code))
        }
    }
}
