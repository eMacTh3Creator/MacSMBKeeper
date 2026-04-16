import SwiftUI

struct HelpView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    gettingStarted
                    sharesSection
                    menuBarSection
                    headlessSection
                    dragDropSection
                    troubleshooting
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Link("View on GitHub", destination: URL(string: "https://github.com/\(AppSettings.githubRepo)")!)
                    .font(.caption)
                Spacer()
                Button("Done") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 560)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "externaldrive.connected.to.line.below.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mac SMB Keeper Help")
                    .font(.title2.bold())
                Text("Version \(AppSettings.currentVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var gettingStarted: some View {
        helpSection("Getting Started") {
            Text("Mac SMB Keeper lives in your menu bar and automatically keeps your SMB network shares connected. It monitors shares every 30 seconds and reconnects any that have dropped.")
        }
    }

    @ViewBuilder
    private var sharesSection: some View {
        helpSection("Managing Shares") {
            helpItem("Adding a share", "Click the + button in the toolbar or choose File > Add Share (Cmd+N). Enter the host address, share name, and optional credentials.")
            helpItem("Editing a share", "Select a share in the sidebar and click Edit in the detail view, or right-click and choose Edit.")
            helpItem("Deleting shares", "Select one or more shares and press Delete, use the context menu, or click Delete in the detail view. Saved credentials are also removed from Keychain.")
            helpItem("Multi-select", "Hold Cmd or Shift to select multiple shares. Bulk actions appear in the detail area and toolbar.")
            helpItem("Drag and drop", "Drag an smb:// URL into the window to quickly add a share.")
        }
    }

    @ViewBuilder
    private var menuBarSection: some View {
        helpSection("Menu Bar") {
            helpItem("Status icon", "The menu bar icon reflects overall status: filled when all shares are connected, warning badge when any are disconnected.")
            helpItem("Quick actions", "Click the menu bar icon to see all shares with their status. Click a share to toggle its connection.")
        }
    }

    @ViewBuilder
    private var headlessSection: some View {
        helpSection("Headless Mac Setup") {
            Text("For unattended Macs, enable **Launch at Login** in Settings (Cmd+,) so Mac SMB Keeper starts automatically at boot and keeps your shares connected without manual intervention.")
        }
    }

    @ViewBuilder
    private var dragDropSection: some View {
        helpSection("Keyboard Shortcuts") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                shortcutRow("Cmd+N", "Add new share")
                shortcutRow("Cmd+K", "Connect all shares")
                shortcutRow("Cmd+Shift+K", "Disconnect all shares")
                shortcutRow("Cmd+,", "Open Settings")
                shortcutRow("Cmd+/", "Show Help")
                shortcutRow("Delete", "Delete selected shares")
            }
        }
    }

    @ViewBuilder
    private var troubleshooting: some View {
        helpSection("Troubleshooting") {
            helpItem("Share won't connect", "Verify the host is reachable on your network. Check that the share name matches exactly (case-sensitive). Ensure credentials are correct.")
            helpItem("Keeps disconnecting", "This is often caused by network instability or the remote server timing out idle connections. Mac SMB Keeper will automatically reconnect within 30 seconds.")
            helpItem("Permission denied", "macOS may require you to grant network access. Check System Settings > Privacy & Security if prompted.")
        }
    }

    @ViewBuilder
    private func helpSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    @ViewBuilder
    private func helpItem(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.bold())
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func shortcutRow(_ shortcut: String, _ description: String) -> some View {
        GridRow {
            Text(shortcut)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(description)
                .font(.subheadline)
        }
    }
}
