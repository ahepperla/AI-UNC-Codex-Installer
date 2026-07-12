import SwiftUI

struct DashboardView: View {
    @ObservedObject var state: SetupState
    @State private var pendingInstallWarning: InstallDurationWarning?

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeader(
                        title: "Codex Dashboard",
                        subtitle: "Current setup status, quick actions, diagnostics, and recommended configuration."
                    )

                    statusGrid
                    actions
                    recommendedConfiguration
                }
                .padding(28)
            }

            Divider()

            DiagnosticsView(state: state)
                .frame(width: 380)
        }
        .task {
            await state.refreshDashboard()
        }
        .sheet(isPresented: $state.showResetEverythingSheet) {
            ResetEverythingView(state: state)
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

    private var statusGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.title2.weight(.semibold))

            InfoRow(
                title: "Codex installed",
                value: state.dashboardSnapshot.installation?.isInstalled == true ? "yes" : "no",
                systemImage: "checkmark.seal",
                passed: state.dashboardSnapshot.installation?.isInstalled
            )
            InfoRow(
                title: "Codex version",
                value: state.dashboardSnapshot.installation?.version ?? "unknown",
                systemImage: "number",
                passed: state.dashboardSnapshot.installation?.version != nil
            )
            InfoRow(
                title: "ChatGPT Desktop",
                value: state.dashboardSnapshot.installation?.desktopAppPath ?? "not found",
                systemImage: "macwindow",
                passed: state.dashboardSnapshot.installation?.isDesktopInstalled
            )
            InfoRow(
                title: "Codex CLI",
                value: state.dashboardSnapshot.installation?.cliPath ?? "not found",
                systemImage: "terminal",
                passed: state.dashboardSnapshot.installation?.isCLIInstalled
            )
            InfoRow(
                title: "Codex home",
                value: state.codexHomeDescription,
                systemImage: "house",
                passed: true
            )
            InfoRow(
                title: "Config path",
                value: state.dashboardSnapshot.configSummary.path,
                systemImage: "doc.text",
                passed: state.dashboardSnapshot.configSummary.exists
            )
            InfoRow(
                title: "Workspace",
                value: state.workspaceDirectoryPath,
                systemImage: "folder",
                passed: true
            )
            InfoRow(
                title: "Current model",
                value: state.dashboardSnapshot.configSummary.model ?? "missing",
                systemImage: "cpu",
                passed: CodexModel.approvedModel(id: state.dashboardSnapshot.configSummary.model) != nil
            )
            InfoRow(
                title: "Reasoning effort",
                value: state.dashboardSnapshot.configSummary.reasoningEffort ?? "model default",
                systemImage: "brain.head.profile",
                passed: reasoningEffortIsValid
            )
            InfoRow(
                title: "Provider",
                value: state.dashboardSnapshot.configSummary.provider ?? "missing",
                systemImage: "cloud",
                passed: state.dashboardSnapshot.configSummary.provider == RecommendedConfig.uncCodex.recommendedProvider
            )
            InfoRow(
                title: "Endpoint",
                value: state.dashboardSnapshot.configSummary.endpoint ?? "missing",
                systemImage: "link",
                passed: state.dashboardSnapshot.configSummary.endpoint == RecommendedConfig.uncCodex.endpoint
            )
            InfoRow(
                title: "Key in Keychain",
                value: state.dashboardSnapshot.keychainKeyExists ? "yes" : "no",
                systemImage: "lock",
                passed: state.dashboardSnapshot.keychainKeyExists
            )
            InfoRow(
                title: "LaunchAgent installed",
                value: state.dashboardSnapshot.launchAgentStatus.plistExists ? "yes" : "no",
                systemImage: "calendar.badge.clock",
                passed: state.dashboardSnapshot.launchAgentStatus.plistExists
            )
            InfoRow(
                title: "LaunchAgent loaded",
                value: state.dashboardSnapshot.launchAgentStatus.loaded ? "yes" : "no",
                systemImage: "play.circle",
                passed: state.dashboardSnapshot.launchAgentStatus.loaded
            )
            InfoRow(
                title: "Last endpoint test",
                value: lastTestText,
                systemImage: "bolt.horizontal.circle",
                passed: state.dashboardSnapshot.lastConnectionTest?.success
            )
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.title2.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], alignment: .leading, spacing: 10) {
                if state.dashboardSnapshot.installation?.isDesktopInstalled == true {
                    Button {
                        Task { await state.openCodexDesktopApp(); await state.refreshDashboard() }
                    } label: {
                        Label("Open ChatGPT Desktop", systemImage: "macwindow.and.cursorarrow")
                    }
                }

                if state.dashboardSnapshot.installation?.canLaunchCLI == true {
                    Button {
                        Task { await state.openCodexCLI(); await state.refreshDashboard() }
                    } label: {
                        Label("Open Codex CLI", systemImage: "terminal.fill")
                    }
                }

                Button {
                    pendingInstallWarning = .desktopApp
                } label: {
                    Label(state.codexDesktopInstallButtonTitle, systemImage: "macwindow.badge.plus")
                }

                Button {
                    pendingInstallWarning = .cli
                } label: {
                    Label(state.codexCLIInstallButtonTitle, systemImage: "terminal")
                }

                Button {
                    Task { await state.testConnection(); await state.refreshDashboard() }
                } label: {
                    Label("Test Connection", systemImage: "bolt.horizontal.circle")
                }

                Button {
                    state.openConfigFolder()
                } label: {
                    Label("Open Config Folder", systemImage: "folder")
                }

                Button {
                    state.openWorkspaceFolder()
                } label: {
                    Label("Open Workspace", systemImage: "folder.fill")
                }

                Button {
                    state.revealBackup()
                } label: {
                    Label("Reveal Backup", systemImage: "archivebox")
                }

                Button {
                    Task { await state.reloadLaunchAgent() }
                } label: {
                    Label("Reload LaunchAgent", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    state.reconfigureAPIKey()
                } label: {
                    Label("Reconfigure API Key", systemImage: "key")
                }

                Button {
                    Task { await state.resetCodexConfigFromDashboard() }
                } label: {
                    Label("Reset Codex Config", systemImage: "doc.badge.gearshape")
                }

                Button(role: .destructive) {
                    state.prepareResetEverything()
                } label: {
                    Label("Reset Everything", systemImage: "trash")
                }

                Button {
                    Task { await state.runDiagnostics() }
                } label: {
                    Label("Run Diagnostics", systemImage: "stethoscope")
                }
            }
            .disabled(state.isBusy)

            if !state.installStatusTitle.isEmpty {
                InstallStatusPanel(state: state)
            }
        }
    }

    private var recommendedConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("UNC Configuration")
                    .font(.title2.weight(.semibold))
                Spacer()
                StatusPill(
                    text: state.dashboardSnapshot.recommendedStatus.title,
                    severity: recommendedSeverity
                )
            }

            switch state.dashboardSnapshot.recommendedStatus {
            case .upToDate:
                Label("Codex config uses approved UNC settings.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.secondary)

            case .missingConfig:
                Label("No Codex config was found. Run Recommended Setup to create one.", systemImage: "doc.badge.plus")
                    .foregroundStyle(.secondary)

            case .updateAvailable(let mismatches):
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(mismatches, id: \.self) { mismatch in
                        Label(mismatch, systemImage: "arrow.right.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await state.updateRecommendedConfiguration() }
                } label: {
                    Label("Update Configuration", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isBusy)
            }
        }
    }

    private var recommendedSeverity: DiagnosticSeverity {
        switch state.dashboardSnapshot.recommendedStatus {
        case .upToDate:
            return .pass
        case .updateAvailable:
            return .warning
        case .missingConfig:
            return .fail
        }
    }

    private var lastTestText: String {
        guard let result = state.dashboardSnapshot.lastConnectionTest else {
            return "not run"
        }
        let status = result.success ? "success" : "failed"
        return "\(status), \(result.testedAt.formatted(date: .abbreviated, time: .standard))"
    }

    private var reasoningEffortIsValid: Bool {
        let summary = state.dashboardSnapshot.configSummary
        guard let model = CodexModel.approvedModel(id: summary.model) else {
            return false
        }
        guard let value = summary.reasoningEffort else {
            return !model.supportsReasoningSelection
        }
        guard let effort = CodexReasoningEffort(rawValue: value) else {
            return false
        }
        return model.supportedReasoningEfforts.isEmpty ? false : model.supportedReasoningEfforts.contains(effort)
    }
}
