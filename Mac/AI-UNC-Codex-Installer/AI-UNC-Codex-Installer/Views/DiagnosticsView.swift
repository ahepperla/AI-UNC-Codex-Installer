import AppKit
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var state: SetupState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Diagnostics")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    Task { await state.runDiagnostics() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Run diagnostics")
                .disabled(state.isBusy)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if state.diagnostics.isEmpty {
                        Text("Run diagnostics to check Codex, config, Keychain, LaunchAgent, endpoint, macOS, and app version.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(state.diagnostics) { diagnostic in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(diagnostic.name)
                                        .font(.callout.weight(.semibold))
                                    Spacer()
                                    StatusPill(text: diagnostic.severity.rawValue, severity: diagnostic.severity)
                                }
                                Text(diagnostic.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            HStack {
                Button {
                    copyReport()
                } label: {
                    Label("Copy Report", systemImage: "doc.on.doc")
                }
                .disabled(state.diagnostics.isEmpty)

                Button {
                    Task { await state.sendSupportReport() }
                } label: {
                    Label("Send Support Report", systemImage: "envelope")
                }
                .disabled(state.isBusy)
            }
        }
        .padding(20)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.diagnosticReport.plainText, forType: .string)
        state.statusMessage = "Diagnostic report copied."
    }
}
