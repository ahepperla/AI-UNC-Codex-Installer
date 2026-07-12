import SwiftUI

struct CodexDetectionView: View {
    @ObservedObject var state: SetupState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(
                title: "Detect Codex",
                subtitle: "AI @ UNC ChatGPT Installer searches common macOS app and CLI locations and checks the detected Codex version."
            )

            VStack(alignment: .leading, spacing: 2) {
                InfoRow(
                    title: "Codex installed",
                    value: state.detection?.isInstalled == true ? "yes" : "no",
                    systemImage: "checkmark.seal",
                    passed: state.detection?.isInstalled
                )
                InfoRow(
                    title: "CLI path",
                    value: state.detection?.cliPath ?? "not found",
                    systemImage: "terminal",
                    passed: state.detection?.isCLIInstalled
                )
                InfoRow(
                    title: "Desktop app path",
                    value: state.detection?.desktopAppPath ?? "not found",
                    systemImage: "macwindow",
                    passed: state.detection?.isDesktopInstalled
                )
                InfoRow(
                    title: "Version",
                    value: state.detection?.version ?? "unknown",
                    systemImage: "number",
                    passed: state.detection?.version != nil
                )
            }

            Spacer()

            HStack {
                Button {
                    Task { await state.detectCodex() }
                } label: {
                    Label("Run Detection", systemImage: "magnifyingglass")
                }
                .disabled(state.isBusy)

                Button {
                    state.continueAfterDetection()
                } label: {
                    Label(state.detection?.isInstalled == true ? "Continue" : "Install Options", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isBusy)
            }
        }
    }
}
