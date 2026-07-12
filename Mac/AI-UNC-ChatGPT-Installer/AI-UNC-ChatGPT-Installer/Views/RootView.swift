import AppKit
import SwiftUI

struct RootView: View {
    @StateObject private var state = SetupState()

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(state: state)
            Divider()
            Group {
                if state.showDashboard {
                    DashboardView(state: state)
                } else {
                    WizardContainerView(state: state)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await state.loadInitialState()
        }
    }
}

private struct AppHeader: View {
    @ObservedObject var state: SetupState

    var body: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("AI @ UNC ChatGPT Installer")
                    .font(.title2.weight(.semibold))
                Text("Sets up ChatGPT Desktop and Codex CLI for the UNC endpoint. \(InstallerMetadata.displayText)")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if state.showDashboard {
                Button {
                    Task { await state.refreshDashboard() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(state.isBusy)

                Button {
                    state.startWizard()
                } label: {
                    Label("Run Recommended Setup", systemImage: "wand.and.stars")
                        .frame(minWidth: 190)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(state.isBusy)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
