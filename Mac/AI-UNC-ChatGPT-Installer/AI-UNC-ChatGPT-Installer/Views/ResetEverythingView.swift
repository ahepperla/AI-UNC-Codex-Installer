import SwiftUI

struct ResetEverythingView: View {
    @ObservedObject var state: SetupState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                title: "Reset Everything",
                subtitle: "Remove AI @ UNC ChatGPT Installer Keychain and LaunchAgent setup, then restore a selected Codex config backup."
            )

            VStack(alignment: .leading, spacing: 10) {
                Label("The current config will be backed up before the selected backup is restored.", systemImage: "archivebox")
                Label("The UNC_AZURE_API_KEY Keychain item will be removed.", systemImage: "key.slash")
                Label("The LaunchAgent, helper script, and GUI environment variable will be removed.", systemImage: "calendar.badge.minus")
                Label("The workspace folder and user files are not deleted.", systemImage: "folder")
            }
            .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Restore Backup")
                    .font(.title2.weight(.semibold))

                if state.availableBackupURLs.isEmpty {
                    Text("No timestamped backups were found in \(state.codexConfigDirectoryPath). Choose a backup file manually.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Backup", selection: $state.selectedRestoreBackupURL) {
                        ForEach(state.availableBackupURLs, id: \.self) { url in
                            Text(url.lastPathComponent)
                                .tag(Optional(url))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 420)
                }

                HStack {
                    Button {
                        state.chooseRestoreBackup()
                    } label: {
                        Label("Choose Backup", systemImage: "folder")
                    }

                    if let selected = state.selectedRestoreBackupURL {
                        Text(selected.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                }
            }

            Spacer()

            HStack {
                Button(role: .cancel) {
                    state.showResetEverythingSheet = false
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
                .disabled(state.isBusy)

                Spacer()

                Button(role: .destructive) {
                    Task { await state.resetEverythingAndRestoreBackup() }
                } label: {
                    Label("Reset and Restore", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isBusy || state.selectedRestoreBackupURL == nil)
            }
        }
        .padding(28)
        .frame(width: 640, height: 520)
    }
}
