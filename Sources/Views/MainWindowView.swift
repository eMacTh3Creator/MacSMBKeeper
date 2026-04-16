import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {
    @ObservedObject var shareStore: ShareStore
    @ObservedObject var monitor: SMBMonitorService
    @EnvironmentObject var settings: AppSettings
    @State private var selection: Set<UUID> = []
    @State private var showingAddSheet = false
    @State private var editingShare: SMBShare?
    @State private var showingHelp = false
    @State private var showingBulkDeleteConfirmation = false
    @State private var dragOver = false
    @State private var dropPrefill: SharePrefill?

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
        .sheet(item: $dropPrefill) { prefill in
            ShareEditorView(shareStore: shareStore, prefill: prefill) {
                dropPrefill = nil
            }
        }
        .sheet(item: $editingShare) { share in
            ShareEditorView(shareStore: shareStore, editing: share) {
                editingShare = nil
            }
        }
        .sheet(isPresented: $showingHelp) {
            HelpView { showingHelp = false }
        }
        .alert("Delete \(selection.count) Share\(selection.count == 1 ? "" : "s")?", isPresented: $showingBulkDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteSelected() }
        } message: {
            Text("This will remove the selected shares and their saved credentials from Keychain.")
        }
        .onAppear {
            monitor.start(with: shareStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addShare)) { _ in
            showingAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHelp)) { _ in
            showingHelp = true
        }
        .onDrop(of: [.url, .text, .fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers)
        }
        .overlay {
            if dragOver {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.08))
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.tint)
                        Text("Drop smb:// URL to add share")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List(shareStore.shares, selection: $selection) { share in
            ShareListRow(share: share, status: monitor.status(for: share.id))
                .tag(share.id)
                .contextMenu {
                    shareContextMenu(for: share)
                }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if selection.count > 1 {
                    Button {
                        showingBulkDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Delete Selected Shares")

                    Button {
                        toggleAutoConnectForSelected()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .help("Toggle Auto-Connect for Selected")
                }

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
                    Text("Add an SMB share to keep connected.\nYou can also drag and drop smb:// URLs here.")
                } actions: {
                    Button("Add Share") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        if selection.count > 1 {
            multiSelectionView
        } else if selection.count == 1, let id = selection.first,
                  let share = shareStore.shares.first(where: { $0.id == id }) {
            ShareDetailView(
                share: share,
                status: monitor.status(for: share.id),
                onConnect: { Task { await monitor.connect(share: share) } },
                onDisconnect: { monitor.disconnect(share: share) },
                onEdit: { editingShare = share },
                onDelete: {
                    monitor.disconnect(share: share)
                    shareStore.remove(share)
                    selection.remove(share.id)
                }
            )
        } else {
            homeView
        }
    }

    // MARK: - Home view (neutral state)

    @ViewBuilder
    private var homeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.connected.to.line.below.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Mac SMB Keeper")
                .font(.title2.bold())
                .foregroundStyle(.secondary)

            if shareStore.shares.isEmpty {
                Text("No shares configured yet. Click + to add one.")
                    .foregroundStyle(.tertiary)
            } else {
                let connected = monitor.connectedCount
                let total = shareStore.shares.count
                Text("\(connected) of \(total) share\(total == 1 ? "" : "s") connected")
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button("Connect All") {
                        Task { await monitor.connectAll() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(monitor.allConnected)
                }
            }

            if settings.updateAvailable {
                GroupBox {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Version \(settings.latestVersion) is available")
                        Spacer()
                        Link("Download", destination: URL(string: "https://github.com/\(AppSettings.githubRepo)/releases/latest")!)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    .padding(4)
                }
                .frame(maxWidth: 350)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Multi-selection view

    @ViewBuilder
    private var multiSelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("\(selection.count) shares selected")
                .font(.title2.bold())

            HStack(spacing: 12) {
                Button("Connect Selected") {
                    Task {
                        for id in selection {
                            if let share = shareStore.shares.first(where: { $0.id == id }) {
                                await monitor.connect(share: share)
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Disconnect Selected") {
                    for id in selection {
                        if let share = shareStore.shares.first(where: { $0.id == id }) {
                            monitor.disconnect(share: share)
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button("Enable Auto-Connect") {
                    setAutoConnectForSelected(true)
                }
                .buttonStyle(.bordered)

                Button("Disable Auto-Connect") {
                    setAutoConnectForSelected(false)
                }
                .buttonStyle(.bordered)
            }

            Divider()
                .frame(maxWidth: 300)

            Button("Delete Selected", role: .destructive) {
                showingBulkDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func deleteSelected() {
        for id in selection {
            if let share = shareStore.shares.first(where: { $0.id == id }) {
                monitor.disconnect(share: share)
                shareStore.remove(share)
            }
        }
        selection.removeAll()
    }

    private func toggleAutoConnectForSelected() {
        let allEnabled = selection.allSatisfy { id in
            shareStore.shares.first(where: { $0.id == id })?.autoConnect == true
        }
        setAutoConnectForSelected(!allEnabled)
    }

    private func setAutoConnectForSelected(_ value: Bool) {
        for id in selection {
            if var share = shareStore.shares.first(where: { $0.id == id }) {
                share.autoConnect = value
                shareStore.update(share, password: nil)
            }
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
            selection.remove(share.id)
        }
    }

    // MARK: - Drag and drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            // Try URL first
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.scheme == "smb" else { return }
                    Task { @MainActor in
                        openEditorForURL(url)
                    }
                }
                handled = true
            }
            // Fall back to plain text
            else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let text,
                          let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                          url.scheme == "smb" else { return }
                    Task { @MainActor in
                        openEditorForURL(url)
                    }
                }
                handled = true
            }
        }
        return handled
    }

    private func openEditorForURL(_ url: URL) {
        guard let host = url.host(percentEncoded: false), !host.isEmpty else { return }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let shareName = pathComponents.first ?? ""
        guard !shareName.isEmpty else { return }

        // Extract username if present in the URL (smb://user@host/share)
        let username = url.user(percentEncoded: false) ?? ""

        dropPrefill = SharePrefill(
            host: host,
            shareName: shareName,
            username: username
        )
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
