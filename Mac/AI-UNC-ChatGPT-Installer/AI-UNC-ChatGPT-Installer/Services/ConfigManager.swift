import Foundation

struct CodexHomeLocation: Equatable, Sendable {
    static let environmentVariableName = "CODEX_HOME"

    var directoryURL: URL
    var source: String

    var usesEnvironmentVariable: Bool {
        source == Self.environmentVariableName
    }

    var description: String {
        usesEnvironmentVariable ? "\(Self.environmentVariableName): \(directoryURL.path)" : "Default: \(directoryURL.path)"
    }

    static func resolve(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> CodexHomeLocation {
        if let rawPath = environment[environmentVariableName]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawPath.isEmpty {
            return CodexHomeLocation(
                directoryURL: normalizedURL(for: rawPath, fileManager: fileManager),
                source: environmentVariableName
            )
        }

        return CodexHomeLocation(
            directoryURL: fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true),
            source: "default"
        )
    }

    private static func normalizedURL(for path: String, fileManager: FileManager) -> URL {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url: URL
        if expandedPath.hasPrefix("/") {
            url = URL(fileURLWithPath: expandedPath, isDirectory: true)
        } else {
            url = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(expandedPath, isDirectory: true)
        }
        return url.standardizedFileURL
    }
}

struct ConfigBackupResult: Sendable {
    var backupURL: URL?
    var message: String
}

final class ConfigManager: @unchecked Sendable {
    let codexHome: CodexHomeLocation
    let configDirectory: URL
    let configURL: URL

    private let fileManager: FileManager

    init(fileManager: FileManager = .default, codexHome: CodexHomeLocation? = nil) {
        self.fileManager = fileManager
        let resolvedCodexHome = codexHome ?? CodexHomeLocation.resolve(fileManager: fileManager)
        self.codexHome = resolvedCodexHome
        self.configDirectory = resolvedCodexHome.directoryURL
        self.configURL = configDirectory.appendingPathComponent("config.toml")
    }

    var configExists: Bool {
        fileManager.fileExists(atPath: configURL.path)
    }

    func availableBackups() -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: configDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { $0.lastPathComponent.hasPrefix("config.toml.backup.") }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    func backupExistingConfigIfNeeded() throws -> ConfigBackupResult {
        guard configExists else {
            try ensureConfigDirectoryExists()
            return ConfigBackupResult(backupURL: nil, message: "No existing Codex config was found.")
        }

        let backupURL = configDirectory.appendingPathComponent("config.toml.backup.\(Self.timestamp())")
        try fileManager.copyItem(at: configURL, to: backupURL)
        return ConfigBackupResult(backupURL: backupURL, message: "Backed up existing config to \(backupURL.path).")
    }

    func writeFreshConfig(
        storageMode: APIKeyStorageMode,
        plaintextAPIKey: String? = nil,
        model: String = RecommendedConfig.uncCodex.recommendedModel,
        reasoningEffort: CodexReasoningEffort? = RecommendedConfig.uncCodex.reasoningEffort
    ) throws {
        try ensureConfigDirectoryExists()

        let contents: String
        switch storageMode {
        case .keychain:
            contents = Self.keychainConfig(model: model, reasoningEffort: reasoningEffort)
        case .plaintextConfig:
            guard let plaintextAPIKey, !plaintextAPIKey.isEmpty else {
                throw ConfigManagerError.missingPlaintextAPIKey
            }
            contents = Self.plaintextConfig(apiKey: plaintextAPIKey, model: model, reasoningEffort: reasoningEffort)
        }

        try contents.write(to: configURL, atomically: true, encoding: .utf8)
    }

    func restoreBackup(from backupURL: URL) throws -> ConfigBackupResult {
        try ensureConfigDirectoryExists()

        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw ConfigManagerError.backupMissing(backupURL.path)
        }

        let currentBackup = try backupExistingConfigIfNeeded()
        try replaceConfigAtomically(with: backupURL)
        return currentBackup
    }

    func readSummary() -> ConfigSummary {
        guard configExists, let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return .missing(path: configURL.path)
        }

        return ConfigSummary(
            exists: true,
            path: configURL.path,
            model: value(for: "model", in: contents),
            provider: value(for: "model_provider", in: contents),
            reasoningEffort: value(for: "model_reasoning_effort", in: contents),
            endpoint: value(for: "base_url", in: contents),
            wireAPI: value(for: "wire_api", in: contents),
            usesEnvironmentKey: value(for: "env_key", in: contents) == KeychainManager.serviceName,
            usesPlaintextBearerToken: value(for: "experimental_bearer_token", in: contents) != nil
        )
    }

    func readPlaintextBearerToken() -> String? {
        guard configExists, let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return nil
        }
        return value(for: "experimental_bearer_token", in: contents)
    }

    private func ensureConfigDirectoryExists() throws {
        try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }

    private func replaceConfigAtomically(with sourceURL: URL) throws {
        let tempURL = configDirectory.appendingPathComponent(".config.toml.restore.\(UUID().uuidString)")
        if fileManager.fileExists(atPath: tempURL.path) {
            try fileManager.removeItem(at: tempURL)
        }
        try fileManager.copyItem(at: sourceURL, to: tempURL)

        if fileManager.fileExists(atPath: configURL.path) {
            _ = try fileManager.replaceItemAt(configURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: configURL)
        }
    }

    private func value(for key: String, in contents: String) -> String? {
        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("\(key) =") else { continue }
            guard let equalsIndex = line.firstIndex(of: "=") else { continue }
            let rawValue = line[line.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
            return Self.unquote(rawValue)
        }
        return nil
    }

    private static func unquote(_ value: String) -> String {
        var result = value
        if result.hasPrefix("\""), result.hasSuffix("\""), result.count >= 2 {
            result.removeFirst()
            result.removeLast()
        }
        return result
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func quote(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private static func reasoningLine(for reasoningEffort: CodexReasoningEffort?) -> String {
        guard let reasoningEffort else { return "" }
        return "model_reasoning_effort = \"\(reasoningEffort.rawValue)\"\n"
    }

    static func keychainConfig(
        model: String = RecommendedConfig.uncCodex.recommendedModel,
        reasoningEffort: CodexReasoningEffort? = RecommendedConfig.uncCodex.reasoningEffort
    ) -> String {
        """
        model = "\(quote(model))"
        model_provider = "azure"
        \(reasoningLine(for: reasoningEffort))

        [model_providers.azure]
        name = "Azure OpenAI"
        base_url = "https://azureaiapi.cloud.unc.edu/openai/v1"
        env_key = "UNC_AZURE_API_KEY"
        wire_api = "responses"
        """
    }

    static func plaintextConfig(
        apiKey: String,
        model: String = RecommendedConfig.uncCodex.recommendedModel,
        reasoningEffort: CodexReasoningEffort? = RecommendedConfig.uncCodex.reasoningEffort
    ) -> String {
        """
        model = "\(quote(model))"
        model_provider = "azure"
        \(reasoningLine(for: reasoningEffort))

        [model_providers.azure]
        name = "Azure OpenAI"
        base_url = "https://azureaiapi.cloud.unc.edu/openai/v1"
        experimental_bearer_token = "\(quote(apiKey))"
        wire_api = "responses"
        """
    }
}

enum ConfigManagerError: LocalizedError {
    case missingPlaintextAPIKey
    case backupMissing(String)

    var errorDescription: String? {
        switch self {
        case .missingPlaintextAPIKey:
            return "A plaintext API key is required when writing experimental_bearer_token."
        case .backupMissing(let path):
            return "The selected backup was not found: \(path)"
        }
    }
}
