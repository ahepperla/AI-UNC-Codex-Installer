import AppKit
import Combine
import Foundation

enum WizardStep: Int, CaseIterable, Identifiable, Sendable {
    case welcome
    case detectCodex
    case installCodex
    case apiKey
    case backupConfig
    case writeConfig
    case testConnection
    case installDesktopApp
    case finish

    var id: Int { rawValue }

    static let primarySetupSteps: [WizardStep] = [
        .welcome,
        .apiKey,
        .backupConfig,
        .writeConfig,
        .testConnection,
        .finish
    ]

    static let codexInstallSteps: [WizardStep] = [
        .welcome,
        .detectCodex,
        .installCodex,
        .apiKey,
        .backupConfig,
        .writeConfig,
        .testConnection,
        .finish
    ]

    var usesCodexInstallSidebar: Bool {
        self == .detectCodex || self == .installCodex || self == .installDesktopApp
    }

    var showsInstallStatusPanel: Bool {
        self == .installCodex || self == .installDesktopApp || self == .finish
    }

    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .detectCodex:
            return "Detect Codex"
        case .installCodex:
            return "Install Options"
        case .apiKey:
            return "API Key"
        case .backupConfig:
            return "Backup Config"
        case .writeConfig:
            return "Write Config"
        case .testConnection:
            return "Test Connection"
        case .installDesktopApp:
            return "Desktop App"
        case .finish:
            return "Finish"
        }
    }
}

struct DashboardSnapshot: Sendable {
    var installation: CodexInstallation?
    var configSummary: ConfigSummary
    var keychainKeyExists: Bool
    var launchAgentStatus: LaunchAgentStatus
    var recommendedStatus: RecommendedConfigStatus
    var lastConnectionTest: ConnectionTestResult?

    static func empty(configPath: String) -> DashboardSnapshot {
        DashboardSnapshot(
            installation: nil,
            configSummary: .missing(path: configPath),
            keychainKeyExists: false,
            launchAgentStatus: LaunchAgentStatus(
                plistExists: false,
                helperScriptExists: false,
                loaded: false,
                environmentVariableSet: false
            ),
            recommendedStatus: .missingConfig,
            lastConnectionTest: nil
        )
    }
}

@MainActor
final class SetupState: ObservableObject {
    @Published var currentStep: WizardStep = .welcome
    @Published var showDashboard = false
    @Published var isBusy = false
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    @Published var detection: CodexInstallation?
    @Published var codexInstallSucceeded = false
    @Published var installLog: [String] = []
    @Published var apiKey = ""
    @Published var usePlaintextFallback = false
    @Published var hasExistingConfig = false
    @Published var backupURL: URL?
    @Published var lastConnectionTest: ConnectionTestResult?
    @Published var dashboardSnapshot: DashboardSnapshot
    @Published var diagnostics: [DiagnosticResult] = []
    @Published var diagnosticReport = DiagnosticReport(generatedAt: Date(), results: [])
    @Published var moveInstallerToTrashOnFinish = true
    @Published var launchCodexAfterSetup = true
    @Published var setupReceipt: SetupReceipt?
    @Published var recommendedSetupPausedForCodexInstall = false
    @Published var desktopInstallSkipped = false
    @Published var workspaceDirectoryPath = ""
    @Published var showResetEverythingSheet = false
    @Published var availableBackupURLs: [URL] = []
    @Published var selectedRestoreBackupURL: URL?
    @Published var installStatusTitle = ""
    @Published var installStatusDetail = ""
    @Published var installStatusSeverity: DiagnosticSeverity?
    @Published var selectedReasoningEffort: CodexReasoningEffort = RecommendedConfig.uncCodex.reasoningEffort

    private let codexLocator: CodexLocator
    private let codexInstaller: CodexInstaller
    private let configManager: ConfigManager
    private let keychainManager: KeychainManager
    private let launchAgentManager: LaunchAgentManager
    private let endpointTester: EndpointTester
    private let diagnosticsManager: DiagnosticsManager
    private let recommendedConfigManager: RecommendedConfigManager
    private let appCleanupManager: AppCleanupManager
    private let supportReportManager: SupportReportManager
    private let workspaceManager: WorkspaceManager
    private let runner: ProcessRunner

    private var sessionPlaintextAPIKey: String?

    init(
        codexLocator: CodexLocator = CodexLocator(),
        codexInstaller: CodexInstaller = CodexInstaller(),
        configManager: ConfigManager = ConfigManager(),
        keychainManager: KeychainManager = KeychainManager(),
        launchAgentManager: LaunchAgentManager = LaunchAgentManager(),
        endpointTester: EndpointTester = EndpointTester(),
        diagnosticsManager: DiagnosticsManager = DiagnosticsManager(),
        recommendedConfigManager: RecommendedConfigManager = RecommendedConfigManager(),
        appCleanupManager: AppCleanupManager = AppCleanupManager(),
        supportReportManager: SupportReportManager = SupportReportManager(),
        workspaceManager: WorkspaceManager = WorkspaceManager(),
        runner: ProcessRunner = ProcessRunner()
    ) {
        self.codexLocator = codexLocator
        self.codexInstaller = codexInstaller
        self.configManager = configManager
        self.keychainManager = keychainManager
        self.launchAgentManager = launchAgentManager
        self.endpointTester = endpointTester
        self.diagnosticsManager = diagnosticsManager
        self.recommendedConfigManager = recommendedConfigManager
        self.appCleanupManager = appCleanupManager
        self.supportReportManager = supportReportManager
        self.workspaceManager = workspaceManager
        self.runner = runner
        self.dashboardSnapshot = .empty(configPath: configManager.configURL.path)
        self.workspaceDirectoryPath = workspaceManager.workspaceURL.path
    }

    var selectedStorageMode: APIKeyStorageMode {
        usePlaintextFallback ? .plaintextConfig : .keychain
    }

    var recommendedConfigJSON: String {
        recommendedConfigManager.recommendedJSON()
    }

    var selectedReasoningEffortDescription: String {
        "\(selectedReasoningEffort.label): \(selectedReasoningEffort.helpText)"
    }

    var codexHomeDescription: String {
        configManager.codexHome.description
    }

    var codexConfigDirectoryPath: String {
        configManager.configDirectory.path
    }

    var codexConfigPath: String {
        configManager.configURL.path
    }

    var setupReceiptText: String {
        let receipt = setupReceipt ?? makeSetupReceipt(installation: detection ?? dashboardSnapshot.installation)
        return receipt.plainText
    }

    var currentInstallation: CodexInstallation? {
        detection ?? dashboardSnapshot.installation
    }

    var codexDesktopAppPath: String? {
        currentInstallation?.desktopAppPath
    }

    var codexCLIPath: String? {
        currentInstallation?.cliPath
    }

    var codexInstallationAvailable: Bool {
        codexInstallSucceeded || currentInstallation?.isInstalled == true
    }

    var codexDesktopAppAvailable: Bool {
        currentInstallation?.isDesktopInstalled == true
    }

    var codexCLIAvailable: Bool {
        currentInstallation?.isCLIInstalled == true
    }

    var codexCLIInstallButtonTitle: String {
        codexCLIAvailable ? "Reinstall CLI" : "Install CLI"
    }

    var codexDesktopInstallButtonTitle: String {
        codexDesktopAppAvailable ? "Reinstall Desktop App" : "Install Desktop App"
    }

    func loadInitialState() async {
        workspaceDirectoryPath = workspaceManager.workspaceURL.path
        await refreshDashboard()
        let summary = dashboardSnapshot.configSummary
        showDashboard = summary.exists && summary.mismatches(from: RecommendedConfig.uncCodex).isEmpty
        if !showDashboard {
            currentStep = .welcome
        }
    }

    func startWizard() {
        showDashboard = false
        currentStep = .welcome
        statusMessage = ""
        errorMessage = nil
        codexInstallSucceeded = false
        recommendedSetupPausedForCodexInstall = false
        desktopInstallSkipped = false
        installLog = []
        installStatusTitle = ""
        installStatusDetail = ""
        installStatusSeverity = nil
    }

    func goToDetection() {
        currentStep = .detectCodex
    }

    func detectCodex() async {
        await performBusy("Detecting Codex.") {
            detection = await codexLocator.detectInstallation()
            if detection?.isInstalled == true {
                statusMessage = "Codex was found."
            } else {
                statusMessage = "Codex was not found in the common macOS locations."
            }
        }
    }

    func continueAfterDetection() {
        if detection?.isInstalled == true {
            currentStep = .apiKey
        } else {
            currentStep = .installCodex
        }
    }

    func installCodex(openDownloadPageOnFailure: Bool = false) async {
        beginInstallStatus(
            title: "Installing Codex CLI",
            detail: "Checking available CLI install methods. This may take a few minutes."
        )
        errorMessage = nil
        codexInstallSucceeded = false
        isBusy = true
        statusMessage = "Installing Codex CLI."
        let result = await codexInstaller.installCodex(openDownloadPageOnFailure: openDownloadPageOnFailure) { [weak self] message in
            self?.recordInstallProgress(message)
        }
        detection = await codexLocator.detectInstallation()
        codexInstallSucceeded = result.installed || detection?.isCLIInstalled == true
        await refreshDashboard()
        isBusy = false

        if codexCLIAvailable {
            statusMessage = "Codex CLI installation succeeded. Continue to API key setup."
            finishInstallStatus(
                title: "Codex CLI Installed",
                detail: "The CLI is available. Continue setup when ready.",
                severity: .pass
            )
        } else if result.openedInstallPage {
            statusMessage = "Opened the official Codex page."
            finishInstallStatus(
                title: "Manual Install Needed",
                detail: result.messages.last ?? "The automatic install did not complete, so the official Codex page was opened.",
                severity: .warning
            )
        } else {
            let detail = result.messages.last ?? "Codex installation did not complete."
            statusMessage = detail
            finishInstallStatus(
                title: "Codex CLI Was Not Installed",
                detail: detail,
                severity: .warning
            )
        }
    }

    func skipInstallAndConfigure() {
        currentStep = .apiKey
    }

    func runRecommendedSetup() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            errorMessage = "Enter a UNC Azure OpenAI API key before running setup."
            return
        }

        isBusy = true
        errorMessage = nil
        statusMessage = "Starting recommended setup."
        showDashboard = false
        installLog = []
        backupURL = nil
        lastConnectionTest = nil
        setupReceipt = nil
        recommendedSetupPausedForCodexInstall = false
        desktopInstallSkipped = false
        installStatusTitle = ""
        installStatusDetail = ""
        installStatusSeverity = nil
        defer { isBusy = false }

        do {
            statusMessage = "Preparing Codex workspace."
            let workspaceURL = try workspaceManager.ensureWorkspaceDirectory()
            workspaceDirectoryPath = workspaceURL.path

            currentStep = .apiKey
            statusMessage = "Saving API key."
            if selectedStorageMode == .keychain {
                try keychainManager.saveAPIKey(trimmedKey)
                try launchAgentManager.installFiles()
                let launchResult = await launchAgentManager.loadImmediately()
                guard launchResult.succeeded else {
                    throw SetupError.operationFailed(launchResult.message)
                }
                sessionPlaintextAPIKey = nil
            } else {
                sessionPlaintextAPIKey = trimmedKey
            }
            apiKey = ""

            currentStep = .backupConfig
            statusMessage = "Backing up existing Codex config."
            let backupResult = try configManager.backupExistingConfigIfNeeded()
            backupURL = backupResult.backupURL

            currentStep = .writeConfig
            statusMessage = "Writing recommended Codex config."
            try configManager.writeFreshConfig(
                storageMode: selectedStorageMode,
                plaintextAPIKey: sessionPlaintextAPIKey,
                reasoningEffort: selectedReasoningEffort
            )

            currentStep = .testConnection
            statusMessage = "Testing UNC endpoint."
            let result = await endpointTester.test(apiKey: currentAPIKeyForTesting())
            lastConnectionTest = result

            guard result.success else {
                statusMessage = result.message
                return
            }

            let installation = await codexLocator.detectInstallation()
            detection = installation
            setupReceipt = makeSetupReceipt(installation: installation)

            statusMessage = "Codex is configured for UNC."
            currentStep = .finish
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Recommended setup stopped."
        }
    }

    func saveAPIKeyAndPrepareEnvironment() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            errorMessage = "Enter a UNC Azure OpenAI API key before continuing."
            return
        }

        await performBusy("Saving API key.") {
            let workspaceURL = try workspaceManager.ensureWorkspaceDirectory()
            workspaceDirectoryPath = workspaceURL.path

            if selectedStorageMode == .keychain {
                try keychainManager.saveAPIKey(trimmedKey)
                try launchAgentManager.installFiles()
                let launchResult = await launchAgentManager.loadImmediately()
                guard launchResult.succeeded else {
                    throw SetupError.operationFailed(launchResult.message)
                }
                sessionPlaintextAPIKey = nil
                statusMessage = launchResult.message
            } else {
                sessionPlaintextAPIKey = trimmedKey
                statusMessage = "Plaintext fallback selected. The API key will be written to config.toml."
            }

            apiKey = ""
            prepareBackupStep()
            currentStep = .backupConfig
        }
    }

    func prepareBackupStep() {
        hasExistingConfig = configManager.configExists
        if hasExistingConfig {
            statusMessage = "This installer will create a fresh Codex configuration. Your existing config will be backed up before changes are made."
        } else {
            statusMessage = "No existing Codex config was found."
        }
    }

    func backupAndContinue() async {
        await performBusy("Backing up existing config.") {
            let result = try configManager.backupExistingConfigIfNeeded()
            backupURL = result.backupURL
            statusMessage = result.message
            currentStep = .writeConfig
        }
    }

    func cancelSetup() {
        currentStep = .welcome
        statusMessage = "Setup was cancelled before changing the Codex config."
    }

    func writeFreshConfig() async {
        await performBusy("Writing fresh Codex config.") {
            try configManager.writeFreshConfig(
                storageMode: selectedStorageMode,
                plaintextAPIKey: sessionPlaintextAPIKey,
                reasoningEffort: selectedReasoningEffort
            )
            statusMessage = "Wrote fresh Codex config at \(configManager.configURL.path)."
            currentStep = .testConnection
        }
    }

    func testConnection() async {
        await performBusy("Testing UNC endpoint.") {
            let key = currentAPIKeyForTesting()
            let result = await endpointTester.test(apiKey: key)
            lastConnectionTest = result
            if result.success {
                let installation = await codexLocator.detectInstallation()
                detection = installation
                setupReceipt = makeSetupReceipt(installation: installation)
                statusMessage = "UNC endpoint test succeeded."
                currentStep = .finish
            } else {
                statusMessage = result.message
            }
        }
    }

    func finishSetup() async {
        guard lastConnectionTest?.success == true else {
            errorMessage = "Setup cannot be marked complete until the connection test succeeds."
            currentStep = .testConnection
            return
        }

        let installation = await codexLocator.detectInstallation()
        detection = installation
        setupReceipt = makeSetupReceipt(installation: installation)

        sessionPlaintextAPIKey = nil
        await refreshDashboard()
        showDashboard = true
    }

    func openCodexDesktopDownloadAndWait() {
        openCodexDownloadPage()
    }

    func installCodexCLI() async {
        beginInstallStatus(
            title: "Installing Codex CLI",
            detail: "Checking available CLI install methods. This may take a few minutes."
        )
        errorMessage = nil
        codexInstallSucceeded = false
        isBusy = true
        statusMessage = "Installing Codex CLI."
        let result = await codexInstaller.installCodex(openDownloadPageOnFailure: false) { [weak self] message in
            self?.recordInstallProgress(message)
        }
        let installation = await codexLocator.detectInstallation()
        detection = installation
        codexInstallSucceeded = result.installed || installation.isCLIInstalled
        setupReceipt = makeSetupReceipt(installation: installation)
        await refreshDashboard()
        isBusy = false

        if codexCLIAvailable {
            statusMessage = "Codex CLI is installed. You can open Codex CLI from this screen."
            finishInstallStatus(
                title: "Codex CLI Installed",
                detail: "Use Open Codex CLI to start it from \(workspaceDirectoryPath).",
                severity: .pass
            )
        } else {
            let detail = result.messages.last ?? "Codex CLI installation did not complete."
            statusMessage = detail
            finishInstallStatus(
                title: "Codex CLI Was Not Installed",
                detail: detail,
                severity: .warning
            )
        }
    }

    func installCodexDesktopApp() async {
        beginInstallStatus(
            title: "Installing Codex Desktop",
            detail: "Downloading the Apple Silicon disk image. This may take a few minutes."
        )
        errorMessage = nil
        codexInstallSucceeded = false
        isBusy = true
        statusMessage = "Installing Codex Desktop."
        let result = await codexInstaller.installCodexDesktopApp { [weak self] message in
            self?.recordInstallProgress(message)
        }
        let installation = await codexLocator.detectInstallation()
        detection = installation
        codexInstallSucceeded = result.installed || installation.isDesktopInstalled
        setupReceipt = makeSetupReceipt(installation: installation)
        await refreshDashboard()
        isBusy = false

        if codexDesktopAppAvailable {
            statusMessage = "Codex Desktop is installed. You can open Codex Desktop from this screen."
            finishInstallStatus(
                title: "Codex Desktop Installed",
                detail: installation.desktopAppPath ?? "The Codex desktop app is installed.",
                severity: .pass
            )
        } else if result.openedInstallPage {
            statusMessage = "Opened the official Codex page."
            finishInstallStatus(
                title: "Manual Install Needed",
                detail: result.messages.last ?? "The automatic desktop install did not complete, so the official Codex page was opened.",
                severity: .warning
            )
        } else {
            let detail = result.messages.last ?? "Codex Desktop installation did not complete."
            statusMessage = detail
            finishInstallStatus(
                title: "Codex Desktop Was Not Installed",
                detail: detail,
                severity: .warning
            )
        }
    }

    func chooseWorkspaceDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Codex Workspace Folder"
        panel.prompt = "Use Folder"
        panel.message = "Codex will open in this folder when opened from AI @ UNC Codex Installer."
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: workspaceDirectoryPath, isDirectory: true)

        if panel.runModal() == .OK, let url = panel.url {
            workspaceManager.setWorkspaceURL(url)
            workspaceDirectoryPath = workspaceManager.workspaceURL.path
            statusMessage = "Codex workspace set to \(workspaceDirectoryPath)."
        }
    }

    func resetWorkspaceDirectoryToDefault() {
        workspaceManager.resetToDefault()
        workspaceDirectoryPath = workspaceManager.workspaceURL.path
        statusMessage = "Codex workspace reset to \(workspaceDirectoryPath)."
    }

    func openWorkspaceFolder() {
        do {
            let workspaceURL = try workspaceManager.ensureWorkspaceDirectory()
            workspaceDirectoryPath = workspaceURL.path
            NSWorkspace.shared.open(workspaceURL)
            statusMessage = "Opened Codex workspace folder."
        } catch {
            errorMessage = "Could not open Codex workspace folder: \(error.localizedDescription)"
        }
    }

    func checkForCodexDesktopApp() async {
        await performBusy("Checking for Codex Desktop.") {
            let installation = await codexLocator.detectInstallation()
            detection = installation
            setupReceipt = makeSetupReceipt(installation: installation)

            if installation.isDesktopInstalled {
                statusMessage = "Codex Desktop was found. Continue to finish setup."
            } else {
                statusMessage = "Codex Desktop is not detected yet. Finish installing it, then click Check Again."
            }
        }
    }

    func continueAfterDesktopInstall() async {
        await performBusy("Checking for Codex Desktop.") {
            let installation = await codexLocator.detectInstallation()
            detection = installation
            setupReceipt = makeSetupReceipt(installation: installation)

            guard installation.isDesktopInstalled else {
                currentStep = .installDesktopApp
                statusMessage = "Codex Desktop is not detected yet."
                return
            }

            recommendedSetupPausedForCodexInstall = false
            if lastConnectionTest?.success == true {
                statusMessage = "Codex Desktop is installed. Setup is ready to finish."
                currentStep = .finish
            } else {
                statusMessage = "Codex Desktop is installed. Continue to API key setup."
                currentStep = .apiKey
            }
        }
    }

    func skipDesktopInstallForNow() {
        desktopInstallSkipped = true
        recommendedSetupPausedForCodexInstall = false
        setupReceipt = makeSetupReceipt(installation: detection ?? dashboardSnapshot.installation)
        if lastConnectionTest?.success == true {
            statusMessage = "UNC config is ready. Codex Desktop can be installed later from the dashboard."
            currentStep = .finish
        } else {
            statusMessage = "Codex Desktop skipped for now. Continue to API key setup."
            currentStep = .apiKey
        }
    }

    func finishSetupAndCleanupIfNeeded() async {
        guard lastConnectionTest?.success == true else {
            errorMessage = "Setup cannot be marked complete until the connection test succeeds."
            currentStep = .testConnection
            return
        }

        setupReceipt = makeSetupReceipt(installation: detection ?? dashboardSnapshot.installation)
        promptToSaveSetupReceiptIfWanted()

        await autoLaunchCodexDesktopIfNeeded()

        if moveInstallerToTrashOnFinish {
            await performBusy("Finishing setup.") {
                sessionPlaintextAPIKey = nil
                let cleanupResult = await appCleanupManager.moveCurrentAppToTrashIfPossible()
                switch cleanupResult {
                case .movedToTrash:
                    statusMessage = "Setup complete. AI @ UNC Codex Installer was moved to Trash."
                case .notMoved(let reason):
                    statusMessage = "Setup complete. The installer could not be moved to Trash automatically: \(reason)"
                }
                NSApp.terminate(nil)
            }
        } else {
            await finishSetup()
        }
    }

    func refreshDashboard() async {
        let installation = await codexLocator.detectInstallation()
        let summary = configManager.readSummary()
        let launchStatus = await launchAgentManager.status()
        detection = installation
        dashboardSnapshot = DashboardSnapshot(
            installation: installation,
            configSummary: summary,
            keychainKeyExists: keychainManager.apiKeyExists(),
            launchAgentStatus: launchStatus,
            recommendedStatus: recommendedConfigManager.status(for: summary),
            lastConnectionTest: lastConnectionTest
        )
    }

    func launchCodex() async {
        errorMessage = nil
        let installation = await codexLocator.detectInstallation()
        detection = installation
        codexInstallSucceeded = installation.isInstalled
        setupReceipt = makeSetupReceipt(installation: installation)

        let workspaceURL: URL
        do {
            workspaceURL = try workspaceManager.ensureWorkspaceDirectory()
            workspaceDirectoryPath = workspaceURL.path
        } catch {
            errorMessage = "Could not prepare Codex workspace folder: \(error.localizedDescription)"
            return
        }

        if let appPath = installation.desktopAppPath {
            let url = URL(fileURLWithPath: appPath)
            do {
                try await openApplication(at: url, workspaceURL: workspaceURL)
                statusMessage = "Opened Codex in \(workspaceURL.path)."
            } catch {
                do {
                    try await openApplication(at: url)
                    statusMessage = "Opened Codex. If it does not open the workspace automatically, choose \(workspaceURL.path)."
                } catch {
                    errorMessage = "Could not open Codex app: \(error.localizedDescription)"
                }
            }
            return
        }

        if let cliPath = installation.cliPath {
            await launchCLIInTerminal(cliPath: cliPath, workspaceURL: workspaceURL)
            return
        }

        errorMessage = "Codex is not installed."
    }

    func openCodexDesktopApp() async {
        errorMessage = nil
        let installation = await codexLocator.detectInstallation()
        detection = installation
        codexInstallSucceeded = installation.isInstalled
        setupReceipt = makeSetupReceipt(installation: installation)

        guard let appPath = installation.desktopAppPath else {
            errorMessage = "Codex Desktop is not installed."
            return
        }

        let workspaceURL: URL
        do {
            workspaceURL = try workspaceManager.ensureWorkspaceDirectory()
            workspaceDirectoryPath = workspaceURL.path
        } catch {
            errorMessage = "Could not prepare Codex workspace folder: \(error.localizedDescription)"
            return
        }

        let url = URL(fileURLWithPath: appPath)
        do {
            try await openApplication(at: url, workspaceURL: workspaceURL)
            statusMessage = "Opened Codex Desktop in \(workspaceURL.path)."
        } catch {
            do {
                try await openApplication(at: url)
                statusMessage = "Opened Codex Desktop. If it does not open the workspace automatically, choose \(workspaceURL.path)."
            } catch {
                errorMessage = "Could not open Codex Desktop: \(error.localizedDescription)"
            }
        }
    }

    func openCodexCLI() async {
        errorMessage = nil
        let installation = await codexLocator.detectInstallation()
        detection = installation
        codexInstallSucceeded = installation.isInstalled
        setupReceipt = makeSetupReceipt(installation: installation)

        guard let cliPath = installation.cliPath else {
            errorMessage = "Codex CLI is not installed."
            return
        }

        let workspaceURL: URL
        do {
            workspaceURL = try workspaceManager.ensureWorkspaceDirectory()
            workspaceDirectoryPath = workspaceURL.path
        } catch {
            errorMessage = "Could not prepare Codex workspace folder: \(error.localizedDescription)"
            return
        }

        await launchCLIInTerminal(cliPath: cliPath, workspaceURL: workspaceURL)
    }

    func openConfigFolder() {
        NSWorkspace.shared.open(configManager.configDirectory)
    }

    func openCodexDownloadPage() {
        errorMessage = nil
        statusMessage = "Opened the official Codex page."
        NSWorkspace.shared.open(CodexInstaller.officialInstallURL)
    }

    func revealBackup() {
        guard let backupURL else {
            errorMessage = "No backup has been created during this run."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([backupURL])
    }

    func reloadLaunchAgent() async {
        await performBusy("Reloading LaunchAgent.") {
            let result = await launchAgentManager.reload()
            statusMessage = result.message
            if !result.succeeded {
                throw SetupError.operationFailed(result.message)
            }
            await refreshDashboard()
        }
    }

    func reconfigureAPIKey() {
        showDashboard = false
        currentStep = .apiKey
        apiKey = ""
        errorMessage = nil
        statusMessage = "Enter a new UNC Azure OpenAI API key."
    }

    func resetCodexConfigFromDashboard() async {
        await performBusy("Resetting Codex config.") {
            let previousSummary = configManager.readSummary()
            let token = configManager.readPlaintextBearerToken()
            let mode: APIKeyStorageMode = previousSummary.usesPlaintextBearerToken && token != nil ? .plaintextConfig : .keychain
            let result = try configManager.backupExistingConfigIfNeeded()
            backupURL = result.backupURL
            try configManager.writeFreshConfig(
                storageMode: mode,
                plaintextAPIKey: token,
                reasoningEffort: selectedReasoningEffort
            )
            statusMessage = "Codex config was reset. \(result.message)"
            await refreshDashboard()
        }
    }

    func runDiagnostics() async {
        await performBusy("Running diagnostics.") {
            let results = await diagnosticsManager.runDiagnostics()
            diagnostics = results
            diagnosticReport = DiagnosticReport(generatedAt: Date(), results: results)
            statusMessage = "Diagnostics complete."
        }
    }

    func updateRecommendedConfiguration() async {
        await performBusy("Updating recommended configuration.") {
            let token = configManager.readPlaintextBearerToken()
            let summary = configManager.readSummary()
            let mode: APIKeyStorageMode = summary.usesPlaintextBearerToken && token != nil ? .plaintextConfig : .keychain
            let result = try configManager.backupExistingConfigIfNeeded()
            backupURL = result.backupURL
            try configManager.writeFreshConfig(
                storageMode: mode,
                plaintextAPIKey: token,
                reasoningEffort: selectedReasoningEffort
            )
            statusMessage = "Updated Codex config to the recommended settings. \(result.message)"
            await refreshDashboard()
        }
    }

    func sendSupportReport() async {
        if diagnostics.isEmpty {
            await runDiagnostics()
        }

        let report = [
            setupReceiptText,
            diagnosticReport.plainText
        ].joined(separator: "\n\n")

        do {
            try supportReportManager.openMail(report: report)
            statusMessage = "Opened a support email with the diagnostic report."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareResetEverything() {
        availableBackupURLs = configManager.availableBackups()
        selectedRestoreBackupURL = availableBackupURLs.first
        showResetEverythingSheet = true
        errorMessage = nil
    }

    func chooseRestoreBackup() {
        let panel = NSOpenPanel()
        panel.title = "Choose Codex Config Backup"
        panel.prompt = "Choose Backup"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = configManager.configDirectory

        if panel.runModal() == .OK {
            selectedRestoreBackupURL = panel.url
            if let url = panel.url, !availableBackupURLs.contains(url) {
                availableBackupURLs.insert(url, at: 0)
            }
        }
    }

    func resetEverythingAndRestoreBackup() async {
        guard let selectedRestoreBackupURL else {
            errorMessage = "Choose a Codex config backup before resetting everything."
            return
        }

        await performBusy("Resetting AI @ UNC Codex Installer configuration.") {
            let restoreBackup = try configManager.restoreBackup(from: selectedRestoreBackupURL)
            backupURL = restoreBackup.backupURL
            try keychainManager.deleteAPIKey()
            try await launchAgentManager.removeInstallation()
            statusMessage = "Reset complete. Restored \(selectedRestoreBackupURL.lastPathComponent)."
            showResetEverythingSheet = false
            await refreshDashboard()
        }
    }

    private func currentAPIKeyForTesting() -> String? {
        if selectedStorageMode == .plaintextConfig {
            return sessionPlaintextAPIKey ?? configManager.readPlaintextBearerToken()
        }
        return (try? keychainManager.readAPIKey()) ?? configManager.readPlaintextBearerToken()
    }

    private func makeSetupReceipt(installation: CodexInstallation?) -> SetupReceipt {
        SetupReceipt(
            generatedAt: Date(),
            codexHomePath: configManager.configDirectory.path,
            codexHomeSource: configManager.codexHome.source,
            configPath: configManager.configURL.path,
            backupPath: backupURL?.path,
            launchAgentPath: launchAgentManager.plistURL.path,
            helperScriptPath: launchAgentManager.helperScriptURL.path,
            endpointTestTime: lastConnectionTest?.testedAt,
            endpointTestStatus: lastConnectionTest?.message ?? "not run",
            workspacePath: workspaceDirectoryPath.isEmpty ? workspaceManager.workspaceURL.path : workspaceDirectoryPath,
            reasoningEffort: selectedReasoningEffort.rawValue,
            codexDesktopPath: installation?.desktopAppPath,
            codexCLIPath: installation?.cliPath,
            codexVersion: installation?.version,
            storageMode: selectedStorageMode
        )
    }

    private func promptToSaveSetupReceiptIfWanted() {
        let alert = NSAlert()
        alert.messageText = "Save setup receipt?"
        alert.informativeText = "Would you like to save a copy of the setup receipt before finishing?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save Receipt")
        alert.addButton(withTitle: "Not Now")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Setup Receipt"
        panel.prompt = "Save"
        panel.nameFieldStringValue = defaultSetupReceiptFilename()
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try setupReceiptText.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Setup receipt saved to \(url.path)."
        } catch {
            let saveAlert = NSAlert(error: error)
            saveAlert.messageText = "Could not save setup receipt"
            saveAlert.informativeText = error.localizedDescription
            saveAlert.runModal()
        }
    }

    private func defaultSetupReceiptFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "UNC-Codex-Setup-Receipt-\(formatter.string(from: Date())).txt"
    }

    private func autoLaunchCodexDesktopIfNeeded() async {
        guard launchCodexAfterSetup else { return }
        let workspaceURL: URL
        do {
            workspaceURL = try workspaceManager.ensureWorkspaceDirectory()
            workspaceDirectoryPath = workspaceURL.path
        } catch {
            statusMessage = "Setup complete, but the Codex workspace folder could not be created."
            return
        }

        let installation = await codexLocator.detectInstallation()
        detection = installation
        setupReceipt = makeSetupReceipt(installation: installation)

        guard let appPath = installation.desktopAppPath else {
            return
        }

        do {
            try await openApplication(at: URL(fileURLWithPath: appPath), workspaceURL: workspaceURL)
            statusMessage = "Opened Codex desktop app in \(workspaceURL.path)."
        } catch {
            do {
                try await openApplication(at: URL(fileURLWithPath: appPath))
                statusMessage = "Opened Codex desktop app. If it does not open the workspace automatically, choose \(workspaceURL.path)."
            } catch {
                statusMessage = "Setup complete, but Codex could not be opened automatically."
            }
        }
    }

    private func beginInstallStatus(title: String, detail: String) {
        installLog = []
        installStatusTitle = title
        installStatusDetail = detail
        installStatusSeverity = nil
    }

    private func recordInstallProgress(_ message: String) {
        installLog.append(message)
        installStatusDetail = message
        installStatusSeverity = nil
    }

    private func finishInstallStatus(title: String, detail: String, severity: DiagnosticSeverity) {
        installStatusTitle = title
        installStatusDetail = detail
        installStatusSeverity = severity
    }

    private func performBusy(_ message: String, operation: () async throws -> Void) async {
        isBusy = true
        statusMessage = message
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Action failed."
        }
    }

    private func routeAfterSuccessfulConnectionTest(installation: CodexInstallation) {
        detection = installation
        setupReceipt = makeSetupReceipt(installation: installation)
        statusMessage = "UNC endpoint test succeeded."
        currentStep = .finish
    }

    private func launchCLIInTerminal(cliPath: String, workspaceURL: URL) async {
        let command = cliLaunchCommand(
            cliPath: cliPath,
            workspacePath: workspaceURL.path,
            shouldLoadKeychainAPIKey: configManager.readSummary().usesEnvironmentKey
        )
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """

        do {
            let result = try await runner.run(executable: "/usr/bin/osascript", arguments: ["-e", script])
            if result.succeeded {
                statusMessage = "Opened Codex CLI in Terminal in \(workspaceURL.path)."
            } else {
                errorMessage = "Terminal could not open Codex CLI: \(result.combinedOutput)"
            }
        } catch {
            errorMessage = "Terminal could not open Codex CLI: \(error.localizedDescription)"
        }
    }

    private func cliLaunchCommand(cliPath: String, workspacePath: String, shouldLoadKeychainAPIKey: Bool) -> String {
        var commands = [
            "cd \(shellQuoted(workspacePath)) || exit 1"
        ]

        if shouldLoadKeychainAPIKey {
            commands.append("KEY=\"$(/usr/bin/security find-generic-password -s \(shellQuoted(KeychainManager.serviceName)) -a \"$(/usr/bin/id -un)\" -w 2>/dev/null || true)\"")
            commands.append("if [ -z \"$KEY\" ]; then echo \(shellQuoted("\(KeychainManager.serviceName) was not found in Keychain. Re-run setup or use the plaintext fallback.")); exit 1; fi")
            commands.append("export \(KeychainManager.serviceName)=\"$KEY\"")
            commands.append("unset KEY")
        }

        if let codexHomeEnvironmentValue {
            commands.append("export \(CodexHomeLocation.environmentVariableName)=\(shellQuoted(codexHomeEnvironmentValue))")
        }

        commands.append(shellQuoted(cliPath))
        return commands.joined(separator: "; ")
    }

    private func openApplication(at url: URL, workspaceURL: URL? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let configuration = NSWorkspace.OpenConfiguration()
            if let codexHomeEnvironmentValue {
                var environment = ProcessInfo.processInfo.environment
                environment[CodexHomeLocation.environmentVariableName] = codexHomeEnvironmentValue
                configuration.environment = environment
            }
            if let workspaceURL {
                NSWorkspace.shared.open([workspaceURL], withApplicationAt: url, configuration: configuration) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            } else {
                NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }

    private var codexHomeEnvironmentValue: String? {
        configManager.codexHome.usesEnvironmentVariable ? configManager.configDirectory.path : nil
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

enum SetupError: LocalizedError {
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let message):
            return message
        }
    }
}
