import Foundation

protocol AIToolConfigurator {
    var toolName: String { get }

    func detectInstallation() async -> CodexInstallation
    func writeConfig(storageMode: APIKeyStorageMode, plaintextAPIKey: String?) async throws
    func testConnection(apiKey: String?) async -> ConnectionTestResult
    func runDiagnostics() async -> [DiagnosticResult]
}

final class CodexConfigurator: AIToolConfigurator, @unchecked Sendable {
    let toolName = "Codex"

    private let locator: CodexLocator
    private let configManager: ConfigManager
    private let endpointTester: EndpointTester
    private let diagnosticsManager: DiagnosticsManager

    init(
        locator: CodexLocator = CodexLocator(),
        configManager: ConfigManager = ConfigManager(),
        endpointTester: EndpointTester = EndpointTester(),
        diagnosticsManager: DiagnosticsManager = DiagnosticsManager()
    ) {
        self.locator = locator
        self.configManager = configManager
        self.endpointTester = endpointTester
        self.diagnosticsManager = diagnosticsManager
    }

    func detectInstallation() async -> CodexInstallation {
        await locator.detectInstallation()
    }

    func writeConfig(storageMode: APIKeyStorageMode, plaintextAPIKey: String?) async throws {
        try configManager.writeFreshConfig(storageMode: storageMode, plaintextAPIKey: plaintextAPIKey)
    }

    func testConnection(apiKey: String?) async -> ConnectionTestResult {
        await endpointTester.test(apiKey: apiKey)
    }

    func runDiagnostics() async -> [DiagnosticResult] {
        await diagnosticsManager.runDiagnostics()
    }
}
