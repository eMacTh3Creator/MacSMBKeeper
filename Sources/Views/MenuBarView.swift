import SwiftUI

struct MenuBarView: View {
    @ObservedObject var shareStore: ShareStore
    @ObservedObject var monitor: SMBMonitorService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if shareStore.shares.isEmpty {
            Text("No shares configured")
                .foregroundStyle(.secondary)
        } else {
            ForEach(shareStore.shares) { share in
                ShareMenuRow(share: share, status: monitor.status(for: share.id)) {
                    Task { await monitor.connect(share: share) }
                } onDisconnect: {
                    monitor.disconnect(share: share)
                }
            }

            Divider()

            Button("Connect All") {
                Task { await monitor.connectAll() }
            }
            .keyboardShortcut("k")
        }

        Divider()

        Button("Open Mac SMB Keeper...") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")

        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Mac SMB Keeper") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")

        // Start monitoring on first appearance
        Text("")
            .hidden()
            .task {
                monitor.start(with: shareStore)
                await monitor.connectAll()
            }
    }
}

struct ShareMenuRow: View {
    let share: SMBShare
    let status: ShareStatus
    var onConnect: () -> Void
    var onDisconnect: () -> Void

    var body: some View {
        Button {
            if status.isConnected {
                onDisconnect()
            } else {
                onConnect()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                Text(share.name.isEmpty ? share.shareName : share.name)

                Spacer()

                Text(status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIcon: String {
        switch status {
        case .connected: "circle.fill"
        case .disconnected: "circle"
        case .connecting: "circle.dotted"
        case .error: "exclamationmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .connected: .green
        case .disconnected: .secondary
        case .connecting: .orange
        case .error: .red
        }
    }
}
