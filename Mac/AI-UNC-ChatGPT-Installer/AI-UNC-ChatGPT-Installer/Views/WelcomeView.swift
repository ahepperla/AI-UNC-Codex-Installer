import SwiftUI

struct WelcomeView: View {
    @ObservedObject var state: SetupState
    @State private var showAdvanced = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(
                    title: "Recommended Setup",
                    subtitle: "Paste the UNC API key, then run the guided setup."
                )

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UNC Azure OpenAI API key")
                            .font(.headline)

                        SecureField("Paste API key", text: $state.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                            .frame(maxWidth: 560)
                            .disabled(state.isBusy)

                        Text(state.apiKeyFieldHelpText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()
                        .frame(maxWidth: 620)

                    ModelAndReasoningControls(
                        selectedModel: $state.selectedModel,
                        selectedReasoningEffort: $state.selectedReasoningEffort,
                        isDisabled: state.isBusy
                    )

                    HStack(alignment: .center, spacing: 16) {
                        Button {
                            Task { await state.runRecommendedSetup() }
                        } label: {
                            Label("Run Recommended Setup", systemImage: "checkmark.circle.fill")
                                .frame(minWidth: 230)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        .disabled(state.isBusy || !state.canContinueWithAPIKey)
                    }
                    .padding(.leading, 122)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Setup summary")
                            .font(.headline)
                        AlignedIconText("Uses \(state.workspaceDirectoryPath) as the project parent.", systemImage: "folder.fill")
                        AlignedIconText("Writes Codex configuration to \(state.codexConfigDirectoryPath).", systemImage: "doc.text")
                        AlignedIconText("Saves the key in macOS Keychain.", systemImage: "lock.shield")
                        AlignedIconText("Backs up existing Codex config before writing the UNC config.", systemImage: "archivebox")
                        AlignedIconText("Tests the UNC endpoint before marking setup complete.", systemImage: "network")
                    }
                }
                .padding(20)
                .frame(maxWidth: 760, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18))
                )

                DisclosureGroup(isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project parent folder")
                                .font(.headline)

                            Text(state.workspaceDirectoryPath)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            HStack {
                                Button {
                                    state.chooseWorkspaceDirectory()
                                } label: {
                                    Label("Choose Folder", systemImage: "folder")
                                }
                                .disabled(state.isBusy)

                                Button {
                                    state.resetWorkspaceDirectoryToDefault()
                                } label: {
                                    Label("Use Default", systemImage: "arrow.uturn.backward")
                                }
                                .disabled(state.isBusy)
                            }
                        }

                        Divider()

                        Toggle(isOn: $state.usePlaintextFallback) {
                            Text("Write key directly in config.toml")
                        }
                        .toggleStyle(.checkbox)
                        .disabled(state.isBusy)

                        if state.usePlaintextFallback {
                            AlignedIconText(
                                "Use Keychain storage unless support asks for this fallback.",
                                systemImage: "exclamationmark.triangle.fill",
                                color: .orange
                            )
                        }

                        HStack {
                            Button {
                                Task {
                                    state.goToDetection()
                                    await state.detectCodex()
                                }
                            } label: {
                                Label("Manual Wizard", systemImage: "list.bullet.rectangle")
                            }
                            .disabled(state.isBusy)

                            Button {
                                state.showDashboard = true
                                Task { await state.refreshDashboard() }
                            } label: {
                                Label("Dashboard", systemImage: "gauge.with.dots.needle.50percent")
                            }
                            .disabled(state.isBusy)
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Text("Advanced Setup")
                        .font(.headline)
                }
                .frame(maxWidth: 760, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
