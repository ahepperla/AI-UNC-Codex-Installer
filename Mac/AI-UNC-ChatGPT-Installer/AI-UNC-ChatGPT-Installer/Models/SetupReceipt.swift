import Foundation

enum InstallerMetadata {
    static let version = "2026.07.12"
    static let buildDate = "2026-07-12"

    static var displayText: String {
        "Installer \(version) (\(buildDate))"
    }
}

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
    var model: String
    var reasoningEffort: String
    var codexDesktopPath: String?
    var codexCLIPath: String?
    var codexVersion: String?
    var storageMode: APIKeyStorageMode

    var plainText: String {
        let formatter = ISO8601DateFormatter()
        return [
            "AI @ UNC ChatGPT Installer Setup Receipt",
            "Installer version: \(InstallerMetadata.version)",
            "Installer build date: \(InstallerMetadata.buildDate)",
            "Generated: \(formatter.string(from: generatedAt))",
            "",
            "What happened:",
            "- API key handling: \(storageMode.label)",
            "- Fresh config written: \(configPath)",
            "- Endpoint test: \(endpointTestStatus)",
            "- ChatGPT Desktop: \(codexDesktopPath ?? "not detected")",
            "- Codex CLI: \(codexCLIPath ?? "not detected")",
            "- Project parent: \(workspacePath)",
            "",
            "Codex home: \(codexHomePath)",
            "Codex home source: \(codexHomeSource)",
            "Config path: \(configPath)",
            "Backup path: \(backupPath ?? "none created during this run")",
            "LaunchAgent path: \(launchAgentPath)",
            "Helper script path: \(helperScriptPath)",
            "Project parent: \(workspacePath)",
            "Endpoint test: \(endpointTestStatus)",
            "Endpoint test time: \(endpointTestTime.map { formatter.string(from: $0) } ?? "not run")",
            "API key storage: \(storageMode.label)",
            "Model: \(model)",
            "Reasoning effort: \(reasoningEffort)",
            "ChatGPT Desktop app: \(codexDesktopPath ?? "not detected")",
            "Codex CLI: \(codexCLIPath ?? "not detected")",
            "Codex version: \(codexVersion ?? "unknown")"
        ].joined(separator: "\n")
    }
}
