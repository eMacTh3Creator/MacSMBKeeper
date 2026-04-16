import Foundation
import os

@MainActor
final class ShareStore: ObservableObject {
    @Published var shares: [SMBShare] = []

    private let saveURL: URL
    private let logger = Logger(subsystem: "com.everettjenkins.MacSMBKeeper", category: "Store")

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MacSMBKeeper", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.saveURL = appDir.appendingPathComponent("shares.json")
        load()
    }

    func add(_ share: SMBShare, password: String?) {
        shares.append(share)
        if let password, !password.isEmpty {
            try? KeychainService.savePassword(password, for: share.id)
        }
        save()
    }

    func update(_ share: SMBShare, password: String?) {
        guard let index = shares.firstIndex(where: { $0.id == share.id }) else { return }
        shares[index] = share
        if let password, !password.isEmpty {
            try? KeychainService.savePassword(password, for: share.id)
        }
        save()
    }

    func remove(_ share: SMBShare) {
        shares.removeAll { $0.id == share.id }
        KeychainService.deletePassword(for: share.id)
        save()
    }

    func updateLastConnected(for id: UUID) {
        guard let index = shares.firstIndex(where: { $0.id == id }) else { return }
        shares[index].lastConnected = Date()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(shares)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            logger.error("Failed to save shares: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: saveURL)
            shares = try JSONDecoder().decode([SMBShare].self, from: data)
        } catch {
            logger.error("Failed to load shares: \(error.localizedDescription)")
        }
    }
}
