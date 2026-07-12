import AppKit
import SwiftUI

struct FinishView: View {
    @ObservedObject var state: SetupState
    @State private var pendingInstallWarning: InstallDurationWarning?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                title: "ChatGPT Is Configured",
                subtitle: "The UNC config is in place and the endpoint test succeeded."
            )

            HStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready for UNC ChatGPT and Codex work.")
                        .font(.title2.weight(.semibold))
                    Text("Config, credential handling, and endpoint verification are complete.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: 720, alignment: .leading)
            .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.green.opacity(0.22))
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("What happened")
                    .font(.headline)
                    .foregroundStyle(.primary)
                CompletionDetailRow("Fresh Codex config written.", systemImage: "doc.badge.gearshape.fill")
                CompletionDetailRow("Codex home: \(state.codexHomeDescription)", systemImage: "house.fill")
                CompletionDetailRow(state.usePlaintextFallback ? "API key stored in config.toml fallback." : "API key saved for UNC_AZURE_API_KEY.", systemImage: state.usePlaintextFallback ? "doc.plaintext" : "lock.shield.fill")
                CompletionDetailRow("UNC endpoint returned the expected response.", systemImage: "checkmark.seal.fill")
                CompletionDetailRow("Workspace: \(state.workspaceDirectoryPath)", systemImage: "folder.fill")
                if state.workspaceUsesLegacyCodexDirectory {
                    CompletionDetailRow("Using existing legacy workspace folder because Documents/Codex already exists.", systemImage: "folder.badge.gearshape")
                }
                CompletionDetailRow(codexStatusText, systemImage: codexStatusIcon)
            }
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next: Install or Open Codex")
                            .font(.headline)
                        Text("UNC configuration is finished. ChatGPT Desktop is recommended for most users; the CLI is optional for Terminal workflows.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    CodexActionRow(
                        title: "ChatGPT Desktop",
                        subtitle: desktopActionSubtitle,
                        statusText: state.codexDesktopAppAvailable ? "Installed" : "Not installed",
                        statusColor: state.codexDesktopAppAvailable ? .green : .secondary,
                        installTitle: state.codexDesktopInstallButtonTitle,
                        installSystemImage: "macwindow.badge.plus",
                        openTitle: "Open ChatGPT Desktop",
                        openSystemImage: "macwindow.and.cursorarrow",
                        canOpen: state.codexDesktopAppAvailable,
                        isBusy: state.isBusy,
                        installAction: { pendingInstallWarning = .desktopApp },
                        openAction: { Task { await state.openCodexDesktopApp() } }
                    )

                    CodexActionRow(
                        title: "CLI",
                        subtitle: cliActionSubtitle,
                        statusText: cliStatusText,
                        statusColor: state.codexCLIAvailable ? .green : .secondary,
                        installTitle: state.codexCLIInstallButtonTitle,
                        installSystemImage: "terminal",
                        openTitle: "Open Codex CLI",
                        openSystemImage: "terminal.fill",
                        canOpen: state.codexCLIAvailable,
                        isBusy: state.isBusy,
                        installAction: { pendingInstallWarning = .cli },
                        openAction: { Task { await state.openCodexCLI() } }
                    )

                    HStack(spacing: 12) {
                        Label("Workspace", systemImage: "folder.fill")
                            .font(.headline)
                            .frame(width: 136, alignment: .leading)

                        Text(state.workspaceDirectoryPath)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button {
                            state.openWorkspaceFolder()
                        } label: {
                            Label("Open Workspace", systemImage: "folder.fill")
                                .frame(width: 150)
                        }
                        .disabled(state.isBusy)
                    }
                    .padding(12)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if !state.installStatusTitle.isEmpty {
                    InstallStatusPanel(state: state)
                }
            }
            .padding(14)
            .frame(maxWidth: 720, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16))
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Setup Receipt")
                    .font(.title2.weight(.semibold))

                Text(state.setupReceiptText)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )

                HStack {
                    Button {
                        copyReceipt()
                    } label: {
                        Label("Copy Receipt", systemImage: "doc.on.doc")
                    }

                    Button {
                        Task { await state.sendSupportReport() }
                    } label: {
                        Label("Send Support Report", systemImage: "envelope")
                    }
                    .disabled(state.isBusy)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Finish Options")
                    .font(.headline)

                Text("Finish will ask whether to save a setup receipt before closing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Toggle(isOn: launchDesktopOnFinishBinding) {
                    Text("Open ChatGPT Desktop when I click Finish")
                }
                .toggleStyle(.checkbox)
                .disabled(!state.codexDesktopAppAvailable || state.isBusy)
                .help(state.codexDesktopAppAvailable ? "Finish will open the installed ChatGPT desktop app." : "Install ChatGPT Desktop before using this option.")

                Toggle(isOn: $state.moveInstallerToTrashOnFinish) {
                    Text("Remove this installer after Finish")
                }
                .toggleStyle(.checkbox)
                .disabled(state.isBusy)
                .help("The app moves itself to Trash when macOS allows it. If the app is running from a read-only location, Finish will still quit cleanly.")
            }
            .padding(14)
            .frame(maxWidth: 720, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16))
            )

            Spacer()

            HStack {
                Spacer()

                Button {
                    Task { await state.finishSetupAndCleanupIfNeeded() }
                } label: {
                    Label("Finish", systemImage: "checkmark.circle.fill")
                        .frame(width: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state.isBusy)
            }
        }
        .installDurationAlert(pending: $pendingInstallWarning) { warning in
            switch warning {
            case .desktopApp:
                Task { await state.installCodexDesktopApp() }
            case .cli:
                Task { await state.installCodexCLI() }
            }
        }
    }

    private func copyReceipt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.setupReceiptText, forType: .string)
        state.statusMessage = "Setup receipt copied."
    }

    private var desktopActionSubtitle: String {
        if let path = state.codexDesktopAppPath, state.codexDesktopAppAvailable {
            return "Recommended for most users. Installed at \(path)"
        }
        return "Recommended for most users. Downloads and installs the Apple Silicon ChatGPT desktop app."
    }

    private var cliActionSubtitle: String {
        if let path = state.codexCLIPath, state.codexCLIAvailable {
            return "Optional Terminal workflow. Installed at \(path)"
        }
        return "Optional Terminal workflow. Installs the codex command."
    }

    private var cliStatusText: String {
        state.codexCLIAvailable ? "Installed" : "Not installed"
    }

    private var launchDesktopOnFinishBinding: Binding<Bool> {
        Binding(
            get: { state.codexDesktopAppAvailable && state.launchCodexAfterSetup },
            set: { state.launchCodexAfterSetup = $0 }
        )
    }

    private var codexStatusText: String {
        if state.codexDesktopAppAvailable && state.codexCLIAvailable {
            return "ChatGPT Desktop app and Codex CLI detected."
        }
        if state.codexDesktopAppAvailable {
            return "ChatGPT Desktop app detected."
        }
        if state.codexCLIAvailable {
            return "Codex CLI detected."
        }
        return "Codex is not installed yet. Choose an option below."
    }

    private var codexStatusIcon: String {
        if state.codexDesktopAppAvailable {
            return "macwindow.and.cursorarrow"
        }
        if state.codexCLIAvailable {
            return "terminal.fill"
        }
        return "square.and.arrow.down"
    }
}

private struct CompletionDetailRow: View {
    var text: String
    var systemImage: String

    init(_ text: String, systemImage: String) {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .font(.callout)
                .frame(width: 20, alignment: .center)

            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CodexActionRow: View {
    var title: String
    var subtitle: String
    var statusText: String
    var statusColor: Color
    var installTitle: String
    var installSystemImage: String
    var openTitle: String
    var openSystemImage: String
    var canOpen: Bool
    var isBusy: Bool
    var installAction: () -> Void
    var openAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if canOpen {
                    Button(action: openAction) {
                        Label(openTitle, systemImage: openSystemImage)
                            .frame(width: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)

                    Button(action: installAction) {
                        Label(installTitle, systemImage: installSystemImage)
                            .frame(width: 180)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                } else {
                    Button(action: installAction) {
                        Label(installTitle, systemImage: installSystemImage)
                            .frame(width: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
