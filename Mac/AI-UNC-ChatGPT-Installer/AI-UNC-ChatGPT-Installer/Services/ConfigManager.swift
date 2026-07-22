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
    let supportDirectory: URL
    let modelCatalogURL: URL

    private let fileManager: FileManager

    init(fileManager: FileManager = .default, codexHome: CodexHomeLocation? = nil) {
        self.fileManager = fileManager
        let resolvedCodexHome = codexHome ?? CodexHomeLocation.resolve(fileManager: fileManager)
        self.codexHome = resolvedCodexHome
        self.configDirectory = resolvedCodexHome.directoryURL
        self.configURL = configDirectory.appendingPathComponent("config.toml")
        self.supportDirectory = configDirectory.appendingPathComponent("unc", isDirectory: true)
        self.modelCatalogURL = supportDirectory.appendingPathComponent("model-catalog.json")
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

        let backupURL = uniqueArchiveURL(prefix: "config.toml.backup")
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
        let modelCatalogPath = try writeModelCatalog() ? modelCatalogURL.path : nil

        let contents: String
        switch storageMode {
        case .keychain:
            contents = Self.keychainConfig(
                model: model,
                reasoningEffort: reasoningEffort,
                modelCatalogPath: modelCatalogPath
            )
        case .plaintextConfig:
            guard let plaintextAPIKey, !plaintextAPIKey.isEmpty else {
                throw ConfigManagerError.missingPlaintextAPIKey
            }
            contents = Self.plaintextConfig(
                apiKey: plaintextAPIKey,
                model: model,
                reasoningEffort: reasoningEffort,
                modelCatalogPath: modelCatalogPath
            )
        }

        try contents.write(to: configURL, atomically: true, encoding: .utf8)
        if storageMode == .plaintextConfig {
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        }
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

    func uninstallUNCConfig() throws -> ConfigBackupResult {
        try ensureConfigDirectoryExists()

        let originalBackup = availableBackups().last
        if let originalBackup {
            let currentBackup = try backupExistingConfigIfNeeded()
            try replaceConfigAtomically(with: originalBackup)
            return ConfigBackupResult(
                backupURL: currentBackup.backupURL,
                message: "Restored \(originalBackup.lastPathComponent)."
            )
        }

        guard configExists else {
            return ConfigBackupResult(backupURL: nil, message: "No Codex config was present.")
        }

        let removedURL = uniqueArchiveURL(prefix: "config.toml.removed")
        try fileManager.moveItem(at: configURL, to: removedURL)
        return ConfigBackupResult(
            backupURL: removedURL,
            message: "No prior backup was available. Moved current config to \(removedURL.path)."
        )
    }

    func removeInstallerSupportFiles() throws {
        if fileManager.fileExists(atPath: supportDirectory.path) {
            try fileManager.removeItem(at: supportDirectory)
        }
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
            modelCatalogPath: value(for: "model_catalog_json", in: contents),
            modelCatalogExists: modelCatalogExists(in: contents),
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

    private func ensureSupportDirectoryExists() throws {
        try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    }

    private func writeModelCatalog() throws -> Bool {
        try ensureSupportDirectoryExists()

        let rawCatalogData: Data?
        do {
            rawCatalogData = try readCurrentCodexCatalog()
        } catch {
            return false
        }

        guard let rawCatalogData,
              let data = try? Self.filteredModelCatalog(from: rawCatalogData) else {
            return false
        }

        try data.write(to: modelCatalogURL, options: .atomic)
        return true
    }

    private func readCurrentCodexCatalog() throws -> Data? {
        guard let codexPath = codexExecutableCandidates().first(where: { fileManager.isExecutableFile(atPath: $0) }) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["debug", "models"]
        let tempCodexHome = fileManager.temporaryDirectory
            .appendingPathComponent("ai-unc-chatgpt-installer-codex-home-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempCodexHome, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempCodexHome) }
        process.environment = ProcessInfo.processInfo.environment.merging(["CODEX_HOME": tempCodexHome.path]) { _, new in new }

        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0, !outputData.isEmpty else {
            return nil
        }
        return outputData
    }

    private func codexExecutableCandidates() -> [String] {
        [
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            "\(NSHomeDirectory())/.local/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(NSHomeDirectory())/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(NSHomeDirectory())/Applications/Codex.app/Contents/Resources/codex"
        ]
    }

    private static func filteredModelCatalog(from data: Data) throws -> Data {
        guard var catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = catalog["models"] as? [[String: Any]] else {
            throw ConfigManagerError.invalidModelCatalog
        }

        var currentModelsByID: [String: [String: Any]] = [:]
        for model in models {
            guard let slug = model["slug"] as? String, currentModelsByID[slug] == nil else { continue }
            currentModelsByID[slug] = model
        }
        let synthesisTemplate = currentModelsByID["gpt-5.5"] ?? models.first
        var filteredModels: [[String: Any]] = []

        for approvedModel in CodexModel.approvedCodexModels {
            let sourceModel: [String: Any]?
            let isSynthesized: Bool
            if let currentModel = currentModelsByID[approvedModel.id] {
                sourceModel = currentModel
                isSynthesized = false
            } else if approvedModel.id.hasPrefix("gpt-5.6-") {
                sourceModel = synthesisTemplate
                isSynthesized = true
            } else {
                sourceModel = nil
                isSynthesized = false
            }

            guard var model = sourceModel else {
                continue
            }

            model["slug"] = approvedModel.id
            model["display_name"] = approvedModel.label
            model["description"] = approvedModel.modelHelpText
            model["priority"] = filteredModels.count
            if let defaultReasoningEffort = approvedModel.defaultReasoningEffort {
                model["default_reasoning_level"] = defaultReasoningEffort.rawValue
                if isSynthesized || !(model["supported_reasoning_levels"] is [[String: Any]]) {
                    model["supported_reasoning_levels"] = approvedModel.catalogReasoningLevels
                }
            }
            if isSynthesized {
                model.removeValue(forKey: "availability_nux")
                model.removeValue(forKey: "upgrade")
            }
            filteredModels.append(model)
        }

        let hasRequiredReasoningFields = filteredModels.allSatisfy { model in
            model["default_reasoning_level"] is String &&
                model["supported_reasoning_levels"] is [[String: Any]]
        }
        guard !filteredModels.isEmpty, hasRequiredReasoningFields else {
            throw ConfigManagerError.invalidModelCatalog
        }

        catalog["fetched_at"] = ISO8601DateFormatter().string(from: Date())
        catalog["models"] = filteredModels
        catalog["source"] = "AI @ UNC ChatGPT Installer filtered from Codex catalog"
        return try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
    }

    private func modelCatalogExists(in contents: String) -> Bool {
        guard let path = value(for: "model_catalog_json", in: contents) else {
            return false
        }
        let expandedPath = NSString(string: path).expandingTildeInPath
        return fileManager.fileExists(atPath: expandedPath)
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

    private func uniqueArchiveURL(prefix: String) -> URL {
        configDirectory.appendingPathComponent(
            "\(prefix).\(Self.timestamp()).\(UUID().uuidString.lowercased())"
        )
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

    private static func modelCatalogLine(for path: String?) -> String {
        guard let path else { return "" }
        return "model_catalog_json = \"\(quote(path))\"\n"
    }

    static func keychainConfig(
        model: String = RecommendedConfig.uncCodex.recommendedModel,
        reasoningEffort: CodexReasoningEffort? = RecommendedConfig.uncCodex.reasoningEffort,
        modelCatalogPath: String?
    ) -> String {
        """
        model = "\(quote(model))"
        model_provider = "azure"
        \(reasoningLine(for: reasoningEffort))
        \(modelCatalogLine(for: modelCatalogPath))

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
        reasoningEffort: CodexReasoningEffort? = RecommendedConfig.uncCodex.reasoningEffort,
        modelCatalogPath: String?
    ) -> String {
        """
        model = "\(quote(model))"
        model_provider = "azure"
        \(reasoningLine(for: reasoningEffort))
        \(modelCatalogLine(for: modelCatalogPath))

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
    case invalidModelCatalog

    var errorDescription: String? {
        switch self {
        case .missingPlaintextAPIKey:
            return "A plaintext API key is required when writing experimental_bearer_token."
        case .backupMissing(let path):
            return "The selected backup was not found: \(path)"
        case .invalidModelCatalog:
            return "Codex did not return a usable model catalog."
        }
    }
}
