import SwiftUI

struct MenuBarView: View {
    @ObservedObject var shareStore: ShareStore
    @ObservedObject var monitor: SMBMonitorService
    var showMainWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if shareStore.shares.isEmpty {
                Text("No shares configured")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(shareStore.shares) { share in
                    ShareMenuRow(share: share, status: monitor.status(for: share.id)) {
                        Task { await monitor.connect(share: share) }
                    } onDisconnect: {
                        monitor.disconnect(share: share)
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            if !shareStore.shares.isEmpty {
                Button("Connect All") {
                    Task { await monitor.connectAll() }
                }
                .keyboardShortcut("c")

                Divider()
                    .padding(.vertical, 4)
            }

            Button("Open Mac SMB Keeper...") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "Mac SMB Keeper" }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    showMainWindow()
                }
            }
            .keyboardShortcut("o")

            Divider()
                .padding(.vertical, 4)

            Button("Quit Mac SMB Keeper") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.vertical, 4)
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
                    .frame(width: 12)

                VStack(alignment: .leading, spacing: 1) {
                    Text(share.name.isEmpty ? share.shareName : share.name)
                        .font(.system(size: 13))
                    Text(share.displayAddress)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(status.label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
