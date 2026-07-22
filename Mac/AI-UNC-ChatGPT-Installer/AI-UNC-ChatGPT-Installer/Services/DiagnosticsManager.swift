import Foundation

final class DiagnosticsManager: @unchecked Sendable {
    private let codexLocator: CodexLocator
    private let configManager: ConfigManager
    private let keychainManager: KeychainManager
    private let launchAgentManager: LaunchAgentManager
    private let endpointTester: EndpointTester
    private let recommendedConfigManager: RecommendedConfigManager

    init(
        codexLocator: CodexLocator = CodexLocator(),
        configManager: ConfigManager = ConfigManager(),
        keychainManager: KeychainManager = KeychainManager(),
        launchAgentManager: LaunchAgentManager = LaunchAgentManager(),
        endpointTester: EndpointTester = EndpointTester(),
        recommendedConfigManager: RecommendedConfigManager = RecommendedConfigManager()
    ) {
        self.codexLocator = codexLocator
        self.configManager = configManager
        self.keychainManager = keychainManager
        self.launchAgentManager = launchAgentManager
        self.endpointTester = endpointTester
        self.recommendedConfigManager = recommendedConfigManager
    }

    func runDiagnostics() async -> [DiagnosticResult] {
        var results: [DiagnosticResult] = []

        let installation = await codexLocator.detectInstallation()
        results.append(result(
            name: "Codex CLI path",
            passed: installation.isCLIInstalled,
            passDetail: installation.cliPath ?? "Codex CLI found.",
            failDetail: "Codex CLI was not found in common terminal locations."
        ))
        results.append(result(
            name: "Codex desktop app path",
            passed: installation.isDesktopInstalled,
            passDetail: installation.desktopAppPath ?? "Codex desktop app found.",
            failDetail: "ChatGPT.app or Codex.app was not found in /Applications or ~/Applications."
        ))
        results.append(DiagnosticResult(
            name: "Codex version",
            severity: installation.version == nil ? .warning : .pass,
            detail: installation.version ?? "Version could not be determined."
        ))

        let summary = configManager.readSummary()
        results.append(DiagnosticResult(
            name: "Codex home",
            severity: .pass,
            detail: configManager.codexHome.description
        ))
        results.append(result(
            name: "Codex config exists",
            passed: summary.exists,
            passDetail: summary.path,
            failDetail: "No config exists at \(summary.path)."
        ))
        results.append(result(
            name: "Config contains expected provider",
            passed: summary.provider == recommendedConfigManager.recommended.recommendedProvider,
            passDetail: "Provider is \(summary.provider ?? "missing").",
            failDetail: "Provider is \(summary.provider ?? "missing"); expected \(recommendedConfigManager.recommended.recommendedProvider)."
        ))
        results.append(result(
            name: "Config contains approved model",
            passed: CodexModel.approvedModel(id: summary.model) != nil,
            passDetail: "Model is \(summary.model ?? "missing").",
            failDetail: "Model is \(summary.model ?? "missing"); expected an approved UNC Codex model."
        ))
        let validReasoningEfforts = CodexReasoningEffort.allCases.map(\.rawValue)
        let approvedModel = CodexModel.approvedModel(id: summary.model)
        let reasoningPassed: Bool = {
            if let reasoningEffort = summary.reasoningEffort {
                guard validReasoningEfforts.contains(reasoningEffort),
                      let parsedEffort = CodexReasoningEffort(rawValue: reasoningEffort),
                      let approvedModel else {
                    return false
                }
                return approvedModel.supportedReasoningEfforts.contains(parsedEffort)
            }
            return approvedModel?.supportsReasoningSelection == false
        }()
        results.append(result(
            name: "Config contains valid reasoning setting",
            passed: reasoningPassed,
            passDetail: "Reasoning effort is \(summary.reasoningEffort ?? "model default").",
            failDetail: "Reasoning effort is \(summary.reasoningEffort ?? "missing"); expected a supported value or model default."
        ))
        results.append(result(
            name: "Config uses UNC model catalog",
            passed: summary.modelCatalogPath != nil && summary.modelCatalogExists,
            passDetail: "Model catalog is \(summary.modelCatalogPath ?? "missing").",
            failDetail: "Run Update Configuration to write the UNC-approved model catalog."
        ))
        results.append(result(
            name: "Config contains expected endpoint",
            passed: summary.endpoint == recommendedConfigManager.recommended.endpoint,
            passDetail: "Endpoint is \(summary.endpoint ?? "missing").",
            failDetail: "Endpoint is \(summary.endpoint ?? "missing"); expected \(recommendedConfigManager.recommended.endpoint)."
        ))
        results.append(result(
            name: "Config contains expected wire API",
            passed: summary.wireAPI == recommendedConfigManager.recommended.wireAPI,
            passDetail: "Wire API is \(summary.wireAPI ?? "missing").",
            failDetail: "Wire API is \(summary.wireAPI ?? "missing"); expected \(recommendedConfigManager.recommended.wireAPI)."
        ))

        switch (summary.usesEnvironmentKey, summary.usesPlaintextBearerToken) {
        case (true, false):
            results.append(DiagnosticResult(
                name: "Authentication mode",
                severity: .pass,
                detail: "Config uses \(KeychainManager.serviceName) from the GUI environment."
            ))

            let keyExists = keychainManager.apiKeyExists()
            results.append(result(
                name: "Keychain key exists",
                passed: keyExists,
                passDetail: "Keychain contains service \(KeychainManager.serviceName).",
                failDetail: "Keychain does not contain service \(KeychainManager.serviceName)."
            ))

            let launchStatus = await launchAgentManager.status()
            results.append(result(
                name: "LaunchAgent plist exists",
                passed: launchStatus.plistExists,
                passDetail: launchAgentManager.plistURL.path,
                failDetail: "LaunchAgent plist is missing at \(launchAgentManager.plistURL.path)."
            ))
            results.append(result(
                name: "LaunchAgent is loaded",
                passed: launchStatus.loaded,
                passDetail: "launchctl reports \(launchAgentManager.label) as loaded.",
                failDetail: "launchctl does not report \(launchAgentManager.label) as loaded."
            ))
            results.append(result(
                name: "GUI environment variable is set",
                passed: launchStatus.environmentVariableSet,
                passDetail: "\(KeychainManager.serviceName) is visible through launchctl getenv.",
                failDetail: "\(KeychainManager.serviceName) is not visible through launchctl getenv."
            ))
        case (false, true):
            results.append(DiagnosticResult(
                name: "Authentication mode",
                severity: .warning,
                detail: "Config uses the plaintext bearer-token fallback. Keychain and LaunchAgent checks do not apply."
            ))
        case (false, false):
            results.append(DiagnosticResult(
                name: "Authentication mode",
                severity: .fail,
                detail: "Config does not contain environment-key or plaintext bearer-token authentication."
            ))
        case (true, true):
            results.append(DiagnosticResult(
                name: "Authentication mode",
                severity: .fail,
                detail: "Config contains both environment-key and plaintext bearer-token authentication."
            ))
        }

        let apiKey: String?
        switch (summary.usesEnvironmentKey, summary.usesPlaintextBearerToken) {
        case (true, false):
            apiKey = try? keychainManager.readAPIKey()
        case (false, true):
            apiKey = configManager.readPlaintextBearerToken()
        case (false, false), (true, true):
            apiKey = nil
        }
        let endpointResult = await endpointTester.test(apiKey: apiKey, model: summary.model ?? recommendedConfigManager.recommended.recommendedModel)
        results.append(DiagnosticResult(
            name: "Endpoint reachable",
            severity: endpointResult.httpStatus == nil ? .fail : .pass,
            detail: endpointResult.httpStatus.map { "HTTP \($0)" } ?? endpointResult.message
        ))
        results.append(DiagnosticResult(
            name: "Model responds",
            severity: endpointResult.success ? .pass : .fail,
            detail: endpointResult.message
        ))

        results.append(DiagnosticResult(
            name: "Current macOS version",
            severity: .pass,
            detail: ProcessInfo.processInfo.operatingSystemVersionString
        ))
        results.append(DiagnosticResult(
            name: "App version",
            severity: .pass,
            detail: Self.appVersion
        ))

        return results
    }

    private func result(name: String, passed: Bool, passDetail: String, failDetail: String) -> DiagnosticResult {
        DiagnosticResult(name: name, severity: passed ? .pass : .fail, detail: passed ? passDetail : failDetail)
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }
}
