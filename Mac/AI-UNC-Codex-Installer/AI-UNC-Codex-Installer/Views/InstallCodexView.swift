import SwiftUI

struct InstallCodexView: View {
    @ObservedObject var state: SetupState
    @State private var pendingInstallWarning: InstallDurationWarning?

    var body: some View {
        let cliInstalled = state.codexCLIAvailable
        let desktopInstalled = state.codexDesktopAppAvailable
        let codexInstalled = cliInstalled || desktopInstalled

        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(
                title: "Codex Install Options",
                subtitle: "Advanced install options. Most users can finish UNC setup first and choose Desktop App or CLI on the final screen."
            )

            if cliInstalled {
                Label("Codex CLI is installed.", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else if desktopInstalled {
                Label("Codex Desktop is installed. The CLI install is optional.", systemImage: "macwindow.and.cursorarrow")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            if !state.installStatusTitle.isEmpty {
                InstallStatusPanel(state: state)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Install CLI adds the terminal command for users who prefer command-line Codex.", systemImage: "terminal")
                    Label("Install Desktop App downloads, mounts, copies, and unmounts the Apple Silicon app image.", systemImage: "macwindow.badge.plus")
                    Label("Continue Without Codex still writes and tests the UNC config first.", systemImage: "arrow.right.circle")
                }
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: 720, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.16))
                )
            }

            Spacer()

            HStack {
                if codexInstalled {
                    Button {
                        if state.recommendedSetupPausedForCodexInstall {
                            Task { await state.runRecommendedSetup() }
                        } else {
                            state.skipInstallAndConfigure()
                        }
                    } label: {
                        Label(state.recommendedSetupPausedForCodexInstall ? "Continue Recommended Setup" : "Continue", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.isBusy)

                    Button {
                        pendingInstallWarning = .cli
                    } label: {
                        Label(state.codexCLIInstallButtonTitle, systemImage: "terminal")
                    }
                    .disabled(state.isBusy)
                } else {
                    Button {
                        pendingInstallWarning = .cli
                    } label: {
                        Label(state.codexCLIInstallButtonTitle, systemImage: "terminal")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.isBusy)
                }

                Button {
                    pendingInstallWarning = .desktopApp
                } label: {
                    Label(state.codexDesktopInstallButtonTitle, systemImage: "macwindow.badge.plus")
                }
                .disabled(state.isBusy)

                Button {
                    Task { await state.detectCodex() }
                } label: {
                    Label("Detect Again", systemImage: "arrow.clockwise")
                }
                .disabled(state.isBusy)

                if !codexInstalled {
                    Button {
                        state.skipInstallAndConfigure()
                    } label: {
                        Label("Continue Without Codex", systemImage: "arrow.right")
                    }
                    .disabled(state.isBusy)
                }
            }
        }
        .installDurationAlert(pending: $pendingInstallWarning) { warning in
            switch warning {
            case .desktopApp:
                Task { await state.installCodexDesktopApp() }
            case .cli:
                Task { await state.installCodex() }
            }
        }
    }
}

struct InstallDesktopAppView: View {
    @ObservedObject var state: SetupState
    @State private var pendingInstallWarning: InstallDurationWarning?

    private var desktopInstalled: Bool {
        state.detection?.isDesktopInstalled == true
    }

    private var setupComplete: Bool {
        state.lastConnectionTest?.success == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(
                title: "Install Codex Desktop",
                subtitle: setupComplete
                    ? "UNC setup is ready. Use the final screen buttons to install or open Codex."
                    : "Use this optional screen only if support asks you to check Codex Desktop detection."
            )

            HStack(alignment: .top, spacing: 16) {
                Image(systemName: desktopInstalled ? "checkmark.circle.fill" : "clock.badge.checkmark")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(desktopInstalled ? .green : .orange)

                VStack(alignment: .leading, spacing: 8) {
                    Text(desktopInstalled ? "Codex Desktop was found." : "Waiting for Codex Desktop.")
                        .font(.title2.weight(.semibold))

                    Text(desktopInstalled ? state.detection?.desktopAppPath ?? "Codex Desktop is installed." : "Use Install Desktop App to download, mount, copy, and unmount the Apple Silicon disk image.")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: 720, alignment: .leading)
            .background((desktopInstalled ? Color.green : Color.orange).opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke((desktopInstalled ? Color.green : Color.orange).opacity(0.22))
            )

            VStack(alignment: .leading, spacing: 8) {
                Label(setupComplete ? "UNC config setup is complete." : "Codex Desktop can be installed before UNC config setup.", systemImage: setupComplete ? "checkmark.seal.fill" : "macwindow.badge.plus")
                Label("Codex may ask the user to open or sign in the first time it launches.", systemImage: desktopInstalled ? "macwindow.and.cursorarrow" : "macwindow.badge.plus")
                Label("The installer will not close itself until you finish from the next screen.", systemImage: "lock.open.display")
            }
            .foregroundStyle(.secondary)

            if let path = state.detection?.desktopAppPath {
                InfoRow(
                    title: "Desktop app path",
                    value: path,
                    systemImage: "macwindow",
                    passed: true
                )
            }

            if !state.installStatusTitle.isEmpty {
                InstallStatusPanel(state: state)
            }

            Spacer()

            HStack {
                if desktopInstalled {
                    Button {
                        if state.recommendedSetupPausedForCodexInstall {
                            Task { await state.runRecommendedSetup() }
                        } else {
                            Task { await state.continueAfterDesktopInstall() }
                        }
                    } label: {
                        Label(state.recommendedSetupPausedForCodexInstall ? "Continue Recommended Setup" : "Continue", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(state.isBusy)
                } else {
                    Button {
                        pendingInstallWarning = .desktopApp
                    } label: {
                        Label(state.codexDesktopInstallButtonTitle, systemImage: "macwindow.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(state.isBusy)
                }

                Button {
                    Task { await state.checkForCodexDesktopApp() }
                } label: {
                    Label("Check Again", systemImage: "arrow.clockwise")
                }
                .controlSize(.large)
                .disabled(state.isBusy)

                Button {
                    state.skipDesktopInstallForNow()
                } label: {
                    Label("Skip Desktop App", systemImage: "arrow.right")
                }
                .controlSize(.large)
                .disabled(state.isBusy)
            }
        }
        .installDurationAlert(pending: $pendingInstallWarning) { warning in
            switch warning {
            case .desktopApp:
                Task { await state.installCodexDesktopApp() }
            case .cli:
                break
            }
        }
    }
}
