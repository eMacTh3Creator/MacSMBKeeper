import Foundation

struct SMBShare: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var host: String
    var shareName: String
    var mountPoint: String
    var username: String
    var autoConnect: Bool
    var lastConnected: Date?

    var smbURL: URL? {
        URL(string: "smb://\(host)/\(shareName)")
    }

    var mountURL: URL {
        URL(fileURLWithPath: mountPoint)
    }

    var displayAddress: String {
        "smb://\(host)/\(shareName)"
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        shareName: String = "",
        mountPoint: String = "/Volumes",
        username: String = "",
        autoConnect: Bool = true,
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.shareName = shareName
        self.mountPoint = mountPoint
        self.username = username
        self.autoConnect = autoConnect
        self.lastConnected = lastConnected
    }
}

enum ShareStatus: Sendable {
    case connected
    case disconnected
    case connecting
    case error(String)

    var label: String {
        switch self {
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        case .connecting: "Connecting..."
        case .error(let msg): "Error: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
