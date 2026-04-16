import Foundation
import Combine
import os

@MainActor
final class SMBMonitorService: ObservableObject {
    @Published private(set) var statuses: [UUID: ShareStatus] = [:]
    @Published private(set) var pausedShareIDs: Set<UUID> = []

    private var monitorTask: Task<Void, Never>?
    private let checkInterval: TimeInterval = 30
    private let logger = Logger(subsystem: "com.everettjenkins.MacSMBKeeper", category: "Monitor")

    private weak var shareStore: ShareStore?

    /// In-memory password cache so the 30s reconnect loop doesn't hit the
    /// Keychain (and potentially prompt the user) on every tick. Cleared on
    /// share removal; refreshed on edit via `invalidatePasswordCache(for:)`.
    private var passwordCache: [UUID: String] = [:]

    private func password(for share: SMBShare) -> String? {
        if let cached = passwordCache[share.id] { return cached }
        if let pw = KeychainService.loadPassword(for: share.id) {
            passwordCache[share.id] = pw
            return pw
        }
        return nil
    }

    func invalidatePasswordCache(for id: UUID) {
        passwordCache.removeValue(forKey: id)
    }

    func start(with store: ShareStore) {
        self.shareStore = store
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.checkAllShares()
                try? await Task.sleep(for: .seconds(self.checkInterval))
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func checkAllShares() async {
        guard let store = shareStore else { return }
        for share in store.shares {
            let mounted = SMBMountService.isMounted(share: share)
            let currentStatus = statuses[share.id]

            if mounted {
                statuses[share.id] = .connected
            } else if case .connecting = currentStatus {
                // Don't override connecting status
            } else if pausedShareIDs.contains(share.id) {
                statuses[share.id] = .paused
            } else {
                statuses[share.id] = .disconnected

                // Auto-reconnect if enabled
                if share.autoConnect {
                    await reconnect(share: share)
                }
            }
        }
    }

    func connect(share: SMBShare) async {
        statuses[share.id] = .connecting
        let password = self.password(for: share)

        do {
            try await SMBMountService.mount(share: share, password: password)
            statuses[share.id] = .connected
            logger.info("Connected to \(share.displayAddress)")

            // Update last connected timestamp
            if let store = shareStore {
                store.updateLastConnected(for: share.id)
            }
        } catch {
            statuses[share.id] = .error(error.localizedDescription)
            logger.error("Failed to connect to \(share.displayAddress): \(error.localizedDescription)")
        }
    }

    func disconnect(share: SMBShare) {
        do {
            try SMBMountService.unmount(share: share)
            statuses[share.id] = pausedShareIDs.contains(share.id) ? .paused : .disconnected
            logger.info("Disconnected from \(share.displayAddress)")
        } catch {
            statuses[share.id] = .error(error.localizedDescription)
            logger.error("Failed to disconnect from \(share.displayAddress): \(error.localizedDescription)")
        }
    }

    func connectAll() async {
        guard let store = shareStore else { return }
        for share in store.shares where share.autoConnect {
            if !SMBMountService.isMounted(share: share) {
                await connect(share: share)
            } else {
                statuses[share.id] = .connected
            }
        }
    }

    private func reconnect(share: SMBShare) async {
        logger.info("Auto-reconnecting to \(share.displayAddress)...")
        await connect(share: share)
    }

    func toggleRemount(for share: SMBShare) {
        if pausedShareIDs.contains(share.id) {
            resumeRemount(for: share)
        } else {
            pauseRemount(for: share)
        }
    }

    func pauseRemount(for share: SMBShare) {
        pausedShareIDs.insert(share.id)
        if !SMBMountService.isMounted(share: share) {
            statuses[share.id] = .paused
        }
    }

    func resumeRemount(for share: SMBShare) {
        pausedShareIDs.remove(share.id)
        statuses[share.id] = SMBMountService.isMounted(share: share) ? .connected : .disconnected
    }

    func isRemountPaused(for id: UUID) -> Bool {
        pausedShareIDs.contains(id)
    }

    func forgetShare(id: UUID) {
        pausedShareIDs.remove(id)
        statuses.removeValue(forKey: id)
        passwordCache.removeValue(forKey: id)
    }

    func status(for id: UUID) -> ShareStatus {
        statuses[id] ?? .disconnected
    }

    var allConnected: Bool {
        guard let store = shareStore, !store.shares.isEmpty else { return true }
        return store.shares.allSatisfy { statuses[$0.id]?.isConnected == true }
    }

    var connectedCount: Int {
        statuses.values.filter(\.isConnected).count
    }
}
