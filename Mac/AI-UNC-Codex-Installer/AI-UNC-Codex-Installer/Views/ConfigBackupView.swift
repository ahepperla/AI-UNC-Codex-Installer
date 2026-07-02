import SwiftUI

struct ConfigBackupView: View {
    @ObservedObject var state: SetupState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: "Backup Old Config",
                subtitle: "AI @ UNC Codex Installer creates a fresh Codex config from scratch so stale generated blocks are not carried forward."
            )

            if state.hasExistingConfig {
                VStack(alignment: .leading, spacing: 12) {
                    Label("This installer will create a fresh Codex configuration. Your existing config will be backed up before changes are made.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Backup files use a timestamped name such as config.toml.backup.20260629_151200.")
                        .foregroundStyle(.secondary)
                }
                .font(.title3)
            } else {
                Label("No existing config was found at \(state.codexConfigPath).", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }

            if let backupURL = state.backupURL {
                InfoRow(title: "Backup", value: backupURL.path, systemImage: "archivebox", passed: true)
            }

            Spacer()

            HStack {
                Button {
                    Task { await state.backupAndContinue() }
                } label: {
                    Label(state.hasExistingConfig ? "Backup and Continue" : "Continue", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isBusy)

                if state.hasExistingConfig {
                    Button(role: .cancel) {
                        state.cancelSetup()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .disabled(state.isBusy)
                }
            }
        }
        .onAppear {
            state.prepareBackupStep()
        }
    }
}
