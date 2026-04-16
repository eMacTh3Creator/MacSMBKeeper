import SwiftUI

struct MainWindowView: View {
    @ObservedObject var shareStore: ShareStore
    @ObservedObject var monitor: SMBMonitorService
    @State private var selectedShare: SMBShare?
    @State private var showingAddSheet = false
    @State private var editingShare: SMBShare?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .sheet(isPresented: $showingAddSheet) {
            ShareEditorView(shareStore: shareStore) {
                showingAddSheet = false
            }
        }
        .sheet(item: $editingShare) { share in
            ShareEditorView(shareStore: shareStore, editing: share) {
                editingShare = nil
            }
        }
        .onAppear {
            monitor.start(with: shareStore)
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        List(shareStore.shares, selection: $selectedShare) { share in
            ShareListRow(share: share, status: monitor.status(for: share.id))
                .tag(share)
                .contextMenu {
                    shareContextMenu(for: share)
                }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add SMB Share")
            }
        }
        .overlay {
            if shareStore.shares.isEmpty {
                ContentUnavailableView {
                    Label("No SMB Shares", systemImage: "externaldrive.connected.to.line.below")
                } description: {
                    Text("Click + to add an SMB share to keep connected.")
                } actions: {
                    Button("Add Share") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let share = selectedShare {
            ShareDetailView(
                share: share,
                status: monitor.status(for: share.id),
                onConnect: { Task { await monitor.connect(share: share) } },
                onDisconnect: { monitor.disconnect(share: share) },
                onEdit: { editingShare = share },
                onDelete: {
                    monitor.disconnect(share: share)
                    shareStore.remove(share)
                    selectedShare = nil
                }
            )
        } else {
            ContentUnavailableView(
                "Select a Share",
                systemImage: "sidebar.left",
                description: Text("Choose an SMB share from the sidebar to view its details.")
            )
        }
    }

    @ViewBuilder
    private func shareContextMenu(for share: SMBShare) -> some View {
        let status = monitor.status(for: share.id)
        if status.isConnected {
            Button("Disconnect") { monitor.disconnect(share: share) }
        } else {
            Button("Connect") { Task { await monitor.connect(share: share) } }
        }
        Divider()
        Button("Edit...") { editingShare = share }
        Button("Delete", role: .destructive) {
            monitor.disconnect(share: share)
            shareStore.remove(share)
            if selectedShare == share { selectedShare = nil }
        }
    }
}

struct ShareListRow: View {
    let share: SMBShare
    let status: ShareStatus

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(share.name.isEmpty ? share.shareName : share.name)
                    .font(.system(size: 13, weight: .medium))
                Text(share.host)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
