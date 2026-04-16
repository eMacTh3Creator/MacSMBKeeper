import SwiftUI

@main
struct MacSMBKeeperApp: App {
    @StateObject private var shareStore = ShareStore()
    @StateObject private var monitor = SMBMonitorService()
    @StateObject private var settings = AppSettings()

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
                .environmentObject(settings)
        }
        .defaultSize(width: 700, height: 500)
        .commands {
            appMenuCommands
        }

        Settings {
            SettingsView(settings: settings)
        }
    }

    @CommandsBuilder
    private var appMenuCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Share...") {
                NotificationCenter.default.post(name: .addShare, object: nil)
            }
            .keyboardShortcut("n")
        }
        CommandGroup(after: .newItem) {
            Button("Connect All") {
                Task { await monitor.connectAll() }
            }
            .keyboardShortcut("k")

            Button("Disconnect All") {
                for share in shareStore.shares {
                    monitor.disconnect(share: share)
                }
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .help) {
            Button("Mac SMB Keeper Help") {
                NotificationCenter.default.post(name: .showHelp, object: nil)
            }
            .keyboardShortcut("/")
        }
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

extension Notification.Name {
    static let addShare = Notification.Name("addShare")
    static let showHelp = Notification.Name("showHelp")
}
