import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var permissions = PermissionChecker()

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            permissionsTab
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
            updatesTab
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 480, height: 360)
        .onAppear {
            permissions.checkAll()
        }
    }

    // MARK: - General

    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Mac SMB Keeper at login", isOn: $settings.launchAtLogin)
                Text("When enabled, the app starts automatically after you log in and begins monitoring your SMB shares.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("App") { Text("Mac SMB Keeper") }
                LabeledContent("Version") { Text(AppSettings.currentVersion) }
                LabeledContent("Source") {
                    Link("GitHub", destination: URL(string: "https://github.com/\(AppSettings.githubRepo)")!)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Permissions

    @ViewBuilder
    private var permissionsTab: some View {
        Form {
            Section {
                Text("Mac SMB Keeper needs certain permissions to mount shares, store credentials, and access your network. Grant any missing permissions below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Full Disk Access") {
                permissionRow(
                    status: permissions.fullDiskAccess,
                    title: "Full Disk Access",
                    description: "Required to mount and unmount volumes at /Volumes. Without this, you may see error 1 (EPERM) when disconnecting shares.",
                    action: { PermissionChecker.openFullDiskAccessSettings() },
                    actionLabel: "Open System Settings"
                )
            }

            Section("Local Network") {
                permissionRow(
                    status: permissions.networkAccess,
                    title: "Network Access",
                    description: "Required to reach SMB file servers on your local network. macOS prompts for this on first connection attempt.",
                    action: { PermissionChecker.openNetworkSettings() },
                    actionLabel: "Open Network Settings"
                )
            }

            Section("Keychain") {
                permissionRow(
                    status: permissions.keychainAccess,
                    title: "Keychain Access",
                    description: "Required to securely store and retrieve share passwords. If denied, you may see Keychain error -25293.",
                    action: { PermissionChecker.openKeychainAccess() },
                    actionLabel: "Open Keychain Access"
                )
            }

            Section {
                HStack {
                    Spacer()
                    Button("Recheck All Permissions") {
                        permissions.checkAll()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Updates

    @ViewBuilder
    private var updatesTab: some View {
        Form {
            Section("Automatic Updates") {
                Toggle("Check for updates on launch", isOn: $settings.checkForUpdates)
            }

            Section("Status") {
                HStack {
                    Text("Current version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(AppSettings.currentVersion)
                }

                if settings.updateAvailable {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Version \(settings.latestVersion) is available")
                        Spacer()
                        Link("Download", destination: URL(string: "https://github.com/\(AppSettings.githubRepo)/releases/latest")!)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("You're up to date")
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Check Now") {
                    Task { await settings.checkForNewVersion() }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func permissionRow(
        status: PermissionChecker.Status,
        title: String,
        description: String,
        action: @escaping () -> Void,
        actionLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusBadge(status)
                Text(title)
                    .font(.body.bold())
                Spacer()
                if status == .denied {
                    Button(actionLabel) { action() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else if status == .granted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusBadge(_ status: PermissionChecker.Status) -> some View {
        switch status {
        case .granted:
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
        case .denied:
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
        case .unknown:
            ProgressView()
                .controlSize(.mini)
                .frame(width: 8, height: 8)
        }
    }
}
