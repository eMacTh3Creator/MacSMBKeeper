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
                    shortcutsSection
                    errorCodesSection
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
        .frame(width: 560, height: 620)
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
            helpItem("Drag and drop", "Drag an smb:// URL into the window to open the Add Share dialog with the host and share name pre-filled.")
        }
    }

    @ViewBuilder
    private var menuBarSection: some View {
        helpSection("Menu Bar") {
            helpItem("Status icon", "The menu bar icon reflects overall status: filled when all shares are connected, warning badge when any are disconnected.")
            helpItem("Quick actions", "Click the menu bar icon to see all shares with their status. Click a share to toggle its connection.")
            helpItem("Dock icon", "The app icon and standard menu bar (File, Help) appear when the main window is open, and hide when it is closed.")
        }
    }

    @ViewBuilder
    private var headlessSection: some View {
        helpSection("Headless Mac Setup") {
            Text("For unattended Macs, enable **Launch at Login** in Settings (Cmd+,) so Mac SMB Keeper starts automatically at boot and keeps your shares connected without manual intervention.")
        }
    }

    @ViewBuilder
    private var shortcutsSection: some View {
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
    private var errorCodesSection: some View {
        helpSection("Error Codes Reference") {
            Text("When a mount or unmount fails, Mac SMB Keeper displays an error code. Below are the most common codes and what they mean.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            Group {
                errorRow("Mount error 2", "ENOENT", "The mount point directory does not exist and could not be created. Verify the mount point path is valid.")
                errorRow("Mount error 13", "EACCES", "Permission denied. The username or password is incorrect, or the server rejected the connection. Double-check credentials.")
                errorRow("Mount error 17", "EEXIST", "A volume is already mounted at that path. The share may already be connected, or another volume is using the same mount point.")
                errorRow("Mount error 22", "EINVAL", "Invalid argument. The SMB URL is malformed. Check the host address and share name for typos or special characters.")
                errorRow("Mount error 51", "ENETUNREACH", "Network is unreachable. The Mac cannot reach the server. Check your network connection and ensure the server is on the same network or reachable via VPN.")
                errorRow("Mount error 60", "ETIMEDOUT", "Connection timed out. The server did not respond. It may be offline, firewalled, or the address is wrong.")
                errorRow("Mount error 61", "ECONNREFUSED", "Connection refused. The server is reachable but not accepting SMB connections on port 445. Verify SMB is enabled on the server.")
                errorRow("Mount error 64", "EHOSTDOWN", "Host is down. The server is not responding to network requests. Check that it is powered on and connected.")
                errorRow("Mount error 65", "EHOSTUNREACH", "No route to host. Similar to error 51 but indicates a routing problem. Check network configuration and subnets.")
            }

            Group {
                errorRow("Mount error -6600", "NetFS auth", "NetFS authentication failure. Credentials were rejected by the server. Try re-entering the password in the share editor.")
                errorRow("Mount error -6602", "NetFS URL", "NetFS could not parse the SMB URL. Ensure the host and share name contain only valid characters.")
                errorRow("Mount error -6003", "NetFS mount", "Generic NetFS mount failure. The server may not support the SMB dialect being used, or the share does not exist on the server.")
            }

            Divider().padding(.vertical, 4)

            Group {
                errorRow("Unmount error 1", "EPERM", "Operation not permitted. Another process may be using files on the mounted share. Close any open files and try again.")
                errorRow("Unmount error 16", "EBUSY", "Resource busy. An application has open files or the working directory is set to the mounted share. Close all files and applications using the share.")
            }

            Divider().padding(.vertical, 4)

            Group {
                errorRow("Keychain status -25291", "errSecNotAvailable", "Keychain is not available. This can happen if the login keychain is locked. Unlock it in Keychain Access.")
                errorRow("Keychain status -25299", "errSecDuplicateItem", "Duplicate item. Mac SMB Keeper handles this automatically, but if seen, try removing the share and re-adding it.")
                errorRow("Keychain status -25293", "errSecAuthFailed", "Keychain authentication failed. You may need to unlock the keychain or grant Mac SMB Keeper access in Keychain Access > [item] > Access Control.")
            }
        }
    }

    @ViewBuilder
    private var troubleshooting: some View {
        helpSection("Troubleshooting") {
            helpItem("Share won't connect", "Verify the host is reachable on your network (try ping from Terminal). Check that the share name matches exactly (case-sensitive). Ensure credentials are correct. See Error Codes above for specific error meanings.")
            helpItem("Keeps disconnecting", "This is often caused by network instability or the remote server timing out idle connections. Mac SMB Keeper will automatically reconnect within 30 seconds. If it persists, check for Wi-Fi interference or switch to a wired connection.")
            helpItem("Permission denied", "macOS may require you to grant network access. Check System Settings > Privacy & Security if prompted. Also verify the SMB server allows connections from your user account.")
            helpItem("Mount point conflicts", "If you see error 17 (EEXIST), another volume may be using the same mount path. Use a unique mount point or eject the existing volume first.")
            helpItem("Viewing system logs", "For advanced diagnostics, open Console.app and filter for \"MacSMBKeeper\" to see detailed mount, monitor, and keychain log entries.")
        }
    }

    // MARK: - Helpers

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

    @ViewBuilder
    private func errorRow(_ code: String, _ name: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(code)
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 1)
    }
}
