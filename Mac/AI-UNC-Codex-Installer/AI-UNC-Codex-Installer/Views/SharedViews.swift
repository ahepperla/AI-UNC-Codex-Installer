import SwiftUI

struct WizardContainerView: View {
    @ObservedObject var state: SetupState

    var body: some View {
        let steps = state.currentStep.usesCodexInstallSidebar ? WizardStep.codexInstallSteps : WizardStep.primarySetupSteps
        let currentIndex = steps.firstIndex(of: state.currentStep) ?? 0

        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    StepRow(
                        step: step,
                        stepNumber: index + 1,
                        isCurrent: step == state.currentStep,
                        isCompleted: index < currentIndex,
                        isBusy: state.isBusy
                    )
                }
                Spacer()
            }
            .frame(width: 220)
            .padding(20)
            .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                StatusBanner(state: state)
                Group {
                    switch state.currentStep {
                    case .welcome:
                        WelcomeView(state: state)
                    case .detectCodex:
                        CodexDetectionView(state: state)
                    case .installCodex:
                        InstallCodexView(state: state)
                    case .apiKey:
                        APIKeyView(state: state)
                    case .backupConfig:
                        ConfigBackupView(state: state)
                    case .writeConfig:
                        ConfigWriteView(state: state)
                    case .testConnection:
                        ConnectionTestView(state: state)
                    case .installDesktopApp:
                        InstallDesktopAppView(state: state)
                    case .finish:
                        ScrollView {
                            FinishView(state: state)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(28)
        }
    }
}

private struct StepRow: View {
    var step: WizardStep
    var stepNumber: Int
    var isCurrent: Bool
    var isCompleted: Bool
    var isBusy: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(circleColor)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                } else if isCurrent && isBusy {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                } else {
                    Text("\(stepNumber)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isCurrent ? .white : .secondary)
                }
            }
            .frame(width: 24, height: 24)

            Text(step.title)
                .font(.callout.weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? .primary : .secondary)
        }
        .padding(.vertical, 6)
    }

    private var circleColor: Color {
        if isCompleted || isCurrent {
            return Color.accentColor
        }
        return Color.secondary.opacity(0.18)
    }
}

struct StatusBanner: View {
    @ObservedObject var state: SetupState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = state.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if !state.installStatusTitle.isEmpty && state.currentStep.showsInstallStatusPanel {
                EmptyView()
            } else if state.isBusy {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(state.statusMessage.isEmpty ? "Working..." : state.statusMessage)
                }
            } else if !state.statusMessage.isEmpty {
                Label(state.statusMessage, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum InstallDurationWarning: String, Identifiable {
    case desktopApp
    case cli

    var id: String { rawValue }

    var title: String {
        switch self {
        case .desktopApp:
            return "Desktop App Install May Take a Few Minutes"
        case .cli:
            return "CLI Install May Take a Few Minutes"
        }
    }

    var message: String {
        switch self {
        case .desktopApp:
            return "The installer will download a disk image, mount it, copy Codex.app, and unmount it. Keep AI @ UNC Codex Installer open until the status panel finishes."
        case .cli:
            return "The installer may use Homebrew or npm to download packages. Keep AI @ UNC Codex Installer open until the status panel finishes."
        }
    }

    var confirmTitle: String {
        switch self {
        case .desktopApp:
            return "Install Desktop App"
        case .cli:
            return "Install CLI"
        }
    }
}

extension View {
    func installDurationAlert(
        pending: Binding<InstallDurationWarning?>,
        onConfirm: @escaping (InstallDurationWarning) -> Void
    ) -> some View {
        alert(item: pending) { warning in
            Alert(
                title: Text(warning.title),
                message: Text(warning.message),
                primaryButton: .default(Text(warning.confirmTitle)) {
                    onConfirm(warning)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct InstallStatusPanel: View {
    @ObservedObject var state: SetupState
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                if state.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 20)
                } else {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                        .frame(width: 20)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.installStatusTitle)
                        .font(.callout.weight(.semibold))
                    Text(state.installStatusDetail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !state.installLog.isEmpty {
                DisclosureGroup(isExpanded: $showDetails) {
                    Text(state.installLog.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } label: {
                    Text("Install Details")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(12)
        .background(statusColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(statusColor.opacity(0.22))
        )
    }

    private var statusColor: Color {
        switch state.installStatusSeverity {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        case nil:
            return Color.accentColor
        }
    }

    private var statusIcon: String {
        switch state.installStatusSeverity {
        case .pass:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        case nil:
            return "gearshape.fill"
        }
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.weight(.semibold))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ReasoningEffortDropdown: View {
    @Binding var selection: CodexReasoningEffort
    var isDisabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Reasoning effort")
                    .font(.headline)

                Picker("Reasoning effort", selection: $selection) {
                    ForEach(CodexReasoningEffort.allCases) { effort in
                        Text(effort.label).tag(effort)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 150, alignment: .leading)
                .disabled(isDisabled)
            }

            Text("\(selection.label): \(selection.helpText)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct InfoRow: View {
    var title: String
    var value: String
    var systemImage: String
    var passed: Bool?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
                .frame(width: 22)
            Text(title)
                .frame(width: 190, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var iconColor: Color {
        switch passed {
        case .some(true):
            return .green
        case .some(false):
            return .red
        case .none:
            return .secondary
        }
    }
}

struct StatusPill: View {
    var text: String
    var severity: DiagnosticSeverity

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch severity {
        case .pass:
            return .green.opacity(0.16)
        case .warning:
            return .orange.opacity(0.16)
        case .fail:
            return .red.opacity(0.16)
        }
    }

    private var foregroundColor: Color {
        switch severity {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        }
    }
}
