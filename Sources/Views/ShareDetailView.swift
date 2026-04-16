import SwiftUI

struct ShareDetailView: View {
    let share: SMBShare
    let status: ShareStatus
    var onConnect: () -> Void
    var onDisconnect: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                connectionInfo
                actions
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert("Delete Share", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete \"\(share.name.isEmpty ? share.shareName : share.name)\"? The saved credentials will also be removed from Keychain.")
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "externaldrive.connected.to.line.below.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(share.name.isEmpty ? share.shareName : share.name)
                    .font(.title2.bold())

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(status.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var connectionInfo: some View {
        GroupBox("Connection Details") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Address")
                        .foregroundStyle(.secondary)
                    Text(share.displayAddress)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Host")
                        .foregroundStyle(.secondary)
                    Text(share.host)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Share")
                        .foregroundStyle(.secondary)
                    Text(share.shareName)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Mount Point")
                        .foregroundStyle(.secondary)
                    Text(share.mountPoint)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Username")
                        .foregroundStyle(.secondary)
                    Text(share.username.isEmpty ? "Guest" : share.username)
                }
                GridRow {
                    Text("Auto-Connect")
                        .foregroundStyle(.secondary)
                    Text(share.autoConnect ? "Enabled" : "Disabled")
                }
                if let lastConnected = share.lastConnected {
                    GridRow {
                        Text("Last Connected")
                            .foregroundStyle(.secondary)
                        Text(lastConnected, style: .relative)
                    }
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 12) {
            if status.isConnected {
                Button("Disconnect") { onDisconnect() }
                    .buttonStyle(.bordered)
            } else {
                Button("Connect") { onConnect() }
                    .buttonStyle(.borderedProminent)
            }

            Button("Edit...") { onEdit() }
                .buttonStyle(.bordered)

            Spacer()

            Button("Delete", role: .destructive) {
                showDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
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
