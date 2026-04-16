import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch Mac SMB Keeper at login", isOn: $settings.launchAtLogin)
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $settings.checkForUpdates)

                HStack {
                    Text("Current version: \(AppSettings.currentVersion)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if settings.updateAvailable {
                        Text("v\(settings.latestVersion) available")
                            .foregroundStyle(.orange)
                        Link("Download", destination: URL(string: "https://github.com/\(AppSettings.githubRepo)/releases/latest")!)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    } else {
                        Text("Up to date")
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Check Now") {
                    Task { await settings.checkForNewVersion() }
                }
            }

            Section("About") {
                LabeledContent("App") {
                    Text("Mac SMB Keeper")
                }
                LabeledContent("Version") {
                    Text(AppSettings.currentVersion)
                }
                LabeledContent("Source") {
                    Link("GitHub", destination: URL(string: "https://github.com/\(AppSettings.githubRepo)")!)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 320)
    }
}
