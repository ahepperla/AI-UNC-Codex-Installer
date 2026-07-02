import Foundation

struct SetupReceipt: Sendable {
    var generatedAt: Date
    var codexHomePath: String
    var codexHomeSource: String
    var configPath: String
    var backupPath: String?
    var launchAgentPath: String
    var helperScriptPath: String
    var endpointTestTime: Date?
    var endpointTestStatus: String
    var workspacePath: String
    var reasoningEffort: String
    var codexDesktopPath: String?
    var codexCLIPath: String?
    var codexVersion: String?
    var storageMode: APIKeyStorageMode

    var plainText: String {
        let formatter = ISO8601DateFormatter()
        return [
            "AI @ UNC Codex Installer Setup Receipt",
            "Generated: \(formatter.string(from: generatedAt))",
            "",
            "Codex home: \(codexHomePath)",
            "Codex home source: \(codexHomeSource)",
            "Config path: \(configPath)",
            "Backup path: \(backupPath ?? "none created during this run")",
            "LaunchAgent path: \(launchAgentPath)",
            "Helper script path: \(helperScriptPath)",
            "Codex workspace: \(workspacePath)",
            "Endpoint test: \(endpointTestStatus)",
            "Endpoint test time: \(endpointTestTime.map { formatter.string(from: $0) } ?? "not run")",
            "API key storage: \(storageMode.label)",
            "Reasoning effort: \(reasoningEffort)",
            "Codex desktop app: \(codexDesktopPath ?? "not detected")",
            "Codex CLI: \(codexCLIPath ?? "not detected")",
            "Codex version: \(codexVersion ?? "unknown")"
        ].joined(separator: "\n")
    }
}
