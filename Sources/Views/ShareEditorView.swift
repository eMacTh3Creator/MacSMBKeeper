import SwiftUI

struct ShareEditorView: View {
    @ObservedObject var shareStore: ShareStore
    var editing: SMBShare?
    var prefill: SharePrefill?
    var onDismiss: () -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var shareName: String = ""
    @State private var mountPoint: String = "/Volumes"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var autoConnect: Bool = true

    private var isEditing: Bool { editing != nil }
    private var isValid: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !shareName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Share Details") {
                    TextField("Display Name", text: $name, prompt: Text("My NAS"))
                    TextField("Host / IP Address", text: $host, prompt: Text("192.168.1.100 or nas.local"))
                    TextField("Share Name", text: $shareName, prompt: Text("Media"))
                    TextField("Mount Point", text: $mountPoint, prompt: Text("/Volumes"))
                }

                Section("Authentication") {
                    TextField("Username", text: $username, prompt: Text("Leave empty for guest"))
                    SecureField("Password", text: $password, prompt: Text("Leave empty for guest"))
                }

                Section {
                    Toggle("Auto-connect on startup", isOn: $autoConnect)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add Share") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding(16)
        }
        .frame(width: 450, height: 380)
        .onAppear {
            if let share = editing {
                name = share.name
                host = share.host
                shareName = share.shareName
                mountPoint = share.mountPoint
                username = share.username
                autoConnect = share.autoConnect
                password = KeychainService.loadPassword(for: share.id) ?? ""
            } else if let prefill {
                host = prefill.host
                shareName = prefill.shareName
                name = prefill.shareName
                mountPoint = prefill.mountPoint
                username = prefill.username
            }
        }
    }

    private func save() {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedShareName = shareName.trimmingCharacters(in: .whitespaces)

        if var existing = editing {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.host = trimmedHost
            existing.shareName = trimmedShareName
            existing.mountPoint = mountPoint.trimmingCharacters(in: .whitespaces)
            existing.username = username.trimmingCharacters(in: .whitespaces)
            existing.autoConnect = autoConnect
            shareStore.update(existing, password: password.isEmpty ? nil : password)
        } else {
            let share = SMBShare(
                name: name.trimmingCharacters(in: .whitespaces),
                host: trimmedHost,
                shareName: trimmedShareName,
                mountPoint: mountPoint.trimmingCharacters(in: .whitespaces),
                username: username.trimmingCharacters(in: .whitespaces),
                autoConnect: autoConnect
            )
            shareStore.add(share, password: password.isEmpty ? nil : password)
        }
        onDismiss()
    }
}

struct SharePrefill: Identifiable {
    let id = UUID()
    var host: String
    var shareName: String
    var mountPoint: String = "/Volumes"
    var username: String = ""
}
