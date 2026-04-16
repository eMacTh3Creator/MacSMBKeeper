import SwiftUI

@main
struct MacSMBKeeperApp: App {
    @StateObject private var shareStore = ShareStore()
    @StateObject private var monitor = SMBMonitorService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                shareStore: shareStore,
                monitor: monitor
            )
        } label: {
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.hierarchical)
        }

        Window("Mac SMB Keeper", id: "main") {
            MainWindowView(shareStore: shareStore, monitor: monitor)
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 700, height: 500)
    }

    private var menuBarIcon: String {
        if shareStore.shares.isEmpty {
            return "externaldrive.connected.to.line.below"
        }
        return monitor.allConnected
            ? "externaldrive.connected.to.line.below.fill"
            : "externaldrive.trianglebadge.exclamationmark"
    }
}
