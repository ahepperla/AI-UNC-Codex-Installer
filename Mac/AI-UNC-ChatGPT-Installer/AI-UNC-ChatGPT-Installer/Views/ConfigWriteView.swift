import SwiftUI

struct ConfigWriteView: View {
    @ObservedObject var state: SetupState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: "Write New Config",
                subtitle: "The generated config targets the UNC Azure OpenAI-compatible Responses API endpoint."
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(configPreview)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )

                if state.usePlaintextFallback {
                    Label("The actual file will contain your API key in plaintext.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Label("The API key will not be written to config.toml.", systemImage: "lock.shield")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack {
                Button {
                    Task { await state.writeFreshConfig() }
                } label: {
                    Label("Write Config", systemImage: "doc.badge.gearshape")
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isBusy)
            }
        }
    }

    private var configPreview: String {
        if state.usePlaintextFallback {
            return ConfigManager.plaintextConfig(
                apiKey: "<USER_KEY>",
                model: state.selectedModel.id,
                reasoningEffort: state.selectedReasoningEffort
            )
        }
        return ConfigManager.keychainConfig(
            model: state.selectedModel.id,
            reasoningEffort: state.selectedReasoningEffort
        )
    }
}
