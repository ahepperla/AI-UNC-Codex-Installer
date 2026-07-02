import Darwin
import Foundation

struct LaunchAgentStatus: Sendable {
    var plistExists: Bool
    var helperScriptExists: Bool
    var loaded: Bool
    var environmentVariableSet: Bool
}

struct LaunchAgentOperationResult: Sendable {
    var succeeded: Bool
    var message: String
}

final class LaunchAgentManager: @unchecked Sendable {
    let label = "edu.unc.codex.env"
    let environmentKey = KeychainManager.serviceName

    private let codexHome: CodexHomeLocation
    private let fileManager: FileManager
    private let runner: ProcessRunner

    init(
        fileManager: FileManager = .default,
        runner: ProcessRunner = ProcessRunner(),
        codexHome: CodexHomeLocation? = nil
    ) {
        self.codexHome = codexHome ?? CodexHomeLocation.resolve(fileManager: fileManager)
        self.fileManager = fileManager
        self.runner = runner
    }

    var codexHomeDescription: String {
        codexHome.description
    }

    var supportDirectory: URL {
        codexHome.directoryURL.appendingPathComponent("unc", isDirectory: true)
    }

    var helperScriptURL: URL {
        supportDirectory.appendingPathComponent("load_unc_codex_env.sh")
    }

    var launchAgentsDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
    }

    var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist")
    }

    func installFiles() throws {
        try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)

        try helperScriptContents.write(to: helperScriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperScriptURL.path)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/bin/zsh", helperScriptURL.path],
            "RunAtLoad": true,
            "StandardOutPath": supportDirectory.appendingPathComponent("launchagent.out.log").path,
            "StandardErrorPath": supportDirectory.appendingPathComponent("launchagent.err.log").path
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    func loadImmediately() async -> LaunchAgentOperationResult {
        guard fileManager.fileExists(atPath: plistURL.path) else {
            return LaunchAgentOperationResult(succeeded: false, message: "LaunchAgent plist is not installed.")
        }

        let domain = guiDomain
        var messages: [String] = []

        do {
            let bootstrap = try await runner.run(executable: "/bin/launchctl", arguments: ["bootstrap", domain, plistURL.path])
            if !bootstrap.succeeded {
                messages.append("bootstrap reported: \(bootstrap.combinedOutput)")
                _ = try? await runner.run(executable: "/bin/launchctl", arguments: ["bootout", domain, plistURL.path])
                let retry = try await runner.run(executable: "/bin/launchctl", arguments: ["bootstrap", domain, plistURL.path])
                if !retry.succeeded {
                    return LaunchAgentOperationResult(
                        succeeded: false,
                        message: "LaunchAgent could not be loaded:\n\(retry.combinedOutput)"
                    )
                }
            }

            let kickstart = try await runner.run(executable: "/bin/launchctl", arguments: ["kickstart", "-k", "\(domain)/\(label)"])
            if !kickstart.succeeded {
                messages.append("kickstart reported: \(kickstart.combinedOutput)")
            }

            let helper = try await runner.run(executable: "/bin/zsh", arguments: [helperScriptURL.path])
            if !helper.succeeded {
                return LaunchAgentOperationResult(
                    succeeded: false,
                    message: "LaunchAgent loaded, but the helper could not set the GUI environment variable."
                )
            }

            let status = await status()
            if status.environmentVariableSet {
                return LaunchAgentOperationResult(succeeded: true, message: "LaunchAgent loaded and GUI environment variable is set.")
            }

            messages.append("launchctl getenv did not report \(environmentKey).")
            return LaunchAgentOperationResult(succeeded: false, message: messages.joined(separator: "\n"))
        } catch {
            return LaunchAgentOperationResult(succeeded: false, message: error.localizedDescription)
        }
    }

    func reload() async -> LaunchAgentOperationResult {
        _ = try? await runner.run(executable: "/bin/launchctl", arguments: ["bootout", guiDomain, plistURL.path])
        return await loadImmediately()
    }

    func removeInstallation() async throws {
        _ = try? await runner.run(executable: "/bin/launchctl", arguments: ["bootout", guiDomain, plistURL.path])
        _ = try? await runner.run(executable: "/bin/launchctl", arguments: ["unsetenv", environmentKey])

        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
        }

        if fileManager.fileExists(atPath: helperScriptURL.path) {
            try fileManager.removeItem(at: helperScriptURL)
        }
    }

    func status() async -> LaunchAgentStatus {
        let plistExists = fileManager.fileExists(atPath: plistURL.path)
        let helperExists = fileManager.fileExists(atPath: helperScriptURL.path)
        let loaded = await isLoaded()
        let environmentSet = await isEnvironmentVariableSet()
        return LaunchAgentStatus(
            plistExists: plistExists,
            helperScriptExists: helperExists,
            loaded: loaded,
            environmentVariableSet: environmentSet
        )
    }

    private var guiDomain: String {
        "gui/\(getuid())"
    }

    private var helperScriptContents: String {
        """
        #!/bin/zsh
        set -eu

        KEY="$(/usr/bin/security find-generic-password -s "\(environmentKey)" -a "$(/usr/bin/id -un)" -w 2>/dev/null || true)"
        if [ -z "$KEY" ]; then
          exit 1
        fi

        /bin/launchctl setenv \(environmentKey) "$KEY"
        """
    }

    private func isLoaded() async -> Bool {
        guard fileManager.fileExists(atPath: "/bin/launchctl") else { return false }
        guard let result = try? await runner.run(executable: "/bin/launchctl", arguments: ["print", "\(guiDomain)/\(label)"]) else {
            return false
        }
        return result.succeeded
    }

    private func isEnvironmentVariableSet() async -> Bool {
        guard fileManager.fileExists(atPath: "/bin/launchctl") else { return false }
        guard let result = try? await runner.run(executable: "/bin/launchctl", arguments: ["getenv", environmentKey]) else {
            return false
        }
        return result.succeeded && !result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
