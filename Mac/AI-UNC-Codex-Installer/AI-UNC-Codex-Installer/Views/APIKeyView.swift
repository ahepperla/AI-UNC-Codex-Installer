import SwiftUI

struct APIKeyView: View {
    @ObservedObject var state: SetupState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: "Configure API Key",
                subtitle: "Enter your UNC Azure OpenAI API key. The key is never displayed in logs or diagnostics."
            )

            VStack(alignment: .leading, spacing: 12) {
                SecureField("UNC Azure OpenAI API key", text: $state.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 620)

                Toggle(isOn: $state.usePlaintextFallback) {
                    Text("Advanced fallback: store key directly in config.toml")
                }
                .toggleStyle(.checkbox)

                if state.usePlaintextFallback {
                    Label("This writes the API key in plaintext as experimental_bearer_token. Use Keychain storage unless support explicitly asks for this fallback.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Label("Keychain storage creates a LaunchAgent that loads UNC_AZURE_API_KEY into the GUI login environment.", systemImage: "lock")
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.vertical, 4)

                ModelAndReasoningControls(
                    selectedModel: $state.selectedModel,
                    selectedReasoningEffort: $state.selectedReasoningEffort,
                    isDisabled: state.isBusy
                )
            }

            Spacer()

            HStack {
                Button {
                    Task { await state.saveAPIKeyAndPrepareEnvironment() }
                } label: {
                    Label("Save and Continue", systemImage: "key.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isBusy || state.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
