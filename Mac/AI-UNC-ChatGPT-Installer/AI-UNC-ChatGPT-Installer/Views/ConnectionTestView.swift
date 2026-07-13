import SwiftUI

struct ConnectionTestView: View {
    @ObservedObject var state: SetupState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: "Test Connection",
                subtitle: "Setup is only complete after the UNC endpoint returns the expected model response."
            )

            if let result = state.lastConnectionTest {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatusPill(text: result.success ? "Success" : "Failed", severity: result.success ? .pass : .fail)
                        Text(result.testedAt.formatted(date: .abbreviated, time: .standard))
                            .foregroundStyle(.secondary)
                    }
                    InfoRow(title: "HTTP status", value: result.httpStatus.map(String.init) ?? "none", systemImage: "network", passed: result.success)
                    Text(result.message)
                        .fixedSize(horizontal: false, vertical: true)
                    if let snippet = result.responseSnippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                AlignedIconText(
                    "Ready to POST a Responses API test request to the UNC endpoint.",
                    systemImage: "paperplane",
                    color: .secondary,
                    font: .title3
                )
            }

            Spacer()

            HStack {
                Button {
                    Task { await state.testConnection() }
                } label: {
                    Label("Test Connection", systemImage: "bolt.horizontal.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isBusy)

                if state.lastConnectionTest?.success == true {
                    Button {
                        Task { await state.finishSetup() }
                    } label: {
                        Label("Continue", systemImage: "arrow.right")
                    }
                    .disabled(state.isBusy)
                }
            }
        }
    }
}
