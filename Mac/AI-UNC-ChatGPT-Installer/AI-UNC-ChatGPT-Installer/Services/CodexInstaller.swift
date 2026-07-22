import AppKit
import Foundation

struct CodexInstallResult: Sendable {
    var installed: Bool
    var openedInstallPage: Bool
    var messages: [String]
}

enum CodexInstallerError: LocalizedError {
    case commandFailed(String)
    case appBundleMissing(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .appBundleMissing(let path):
            return "The desktop app was not found in the mounted disk image at \(path)."
        }
    }
}

final class CodexInstaller: @unchecked Sendable {
    static let officialCodexURL = URL(string: "https://openai.com/codex/")!
    static let officialDesktopDownloadURL = URL(string: "https://chatgpt.com/download/")!
    static let appleSiliconDMGURL = URL(string: "https://persistent.oaistatic.com/codex-app-prod/ChatGPT.dmg")!
    static let standaloneCLIInstallerURL = URL(string: "https://chatgpt.com/codex/install.sh")!

    private static let desktopAppBundleNames = ["ChatGPT.app", "Codex.app"]

    private let runner: ProcessRunner
    private let fileManager: FileManager

    init(runner: ProcessRunner = ProcessRunner(), fileManager: FileManager = .default) {
        self.runner = runner
        self.fileManager = fileManager
    }

    func installCodex(
        openDownloadPageOnFailure: Bool = true,
        progress: @escaping @MainActor (String) -> Void
    ) async -> CodexInstallResult {
        var messages: [String] = []

        func record(_ message: String) async {
            messages.append(message)
            await progress(message)
        }

        await record("Downloading the standalone Codex CLI installer.")
        do {
            let workDirectory = fileManager.temporaryDirectory
                .appendingPathComponent("ai-unc-chatgpt-cli-installer-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
            defer {
                try? fileManager.removeItem(at: workDirectory)
            }
            let installerURL = workDirectory.appendingPathComponent("install-codex.sh")

            let download = try await runner.run(
                executable: "/usr/bin/curl",
                arguments: [
                    "--fail",
                    "--location",
                    "--retry", "2",
                    "--output", installerURL.path,
                    Self.standaloneCLIInstallerURL.absoluteString
                ]
            )
            guard download.succeeded else {
                await record("Codex CLI installer download failed:\n\(download.combinedOutput)")
                return await cliInstallFallback(
                    openDownloadPageOnFailure: openDownloadPageOnFailure,
                    messages: messages,
                    progress: progress
                )
            }

            var environment = ProcessInfo.processInfo.environment
            environment["CODEX_NON_INTERACTIVE"] = "1"
            environment["CI"] = "1"

            await record("Running the standalone Codex CLI installer.")
            let command = "printf 'n\\n' | CODEX_NON_INTERACTIVE=1 CI=1 /bin/sh \(shellQuoted(installerURL.path))"
            let installResult = try await runner.run(
                executable: "/bin/sh",
                arguments: ["-c", command],
                environment: environment
            )
            if installResult.succeeded {
                await record("Codex CLI installer finished successfully.")
                return CodexInstallResult(installed: true, openedInstallPage: false, messages: messages)
            }

            await record("Codex CLI installer did not finish cleanly:\n\(installResult.combinedOutput)")
        } catch {
            await record("Codex CLI installer could not run: \(error.localizedDescription)")
        }

        return await cliInstallFallback(
            openDownloadPageOnFailure: openDownloadPageOnFailure,
            messages: messages,
            progress: progress
        )
    }

    private func cliInstallFallback(
        openDownloadPageOnFailure: Bool,
        messages: [String],
        progress: @escaping @MainActor (String) -> Void
    ) async -> CodexInstallResult {
        var messages = messages

        func record(_ message: String) async {
            messages.append(message)
            await progress(message)
        }

        if openDownloadPageOnFailure {
            await MainActor.run {
                _ = NSWorkspace.shared.open(Self.officialCodexURL)
            }
            await record("Automatic installation did not complete. Opened the official Codex page.")
        } else {
            await record("Automatic CLI installation did not complete. Use Install ChatGPT Desktop if you prefer the macOS desktop app.")
        }

        return CodexInstallResult(installed: false, openedInstallPage: openDownloadPageOnFailure, messages: messages)
    }

    func installCodexDesktopApp(
        progress: @escaping @MainActor (String) -> Void
    ) async -> CodexInstallResult {
        var messages: [String] = []
        var mountedPath: String?

        func record(_ message: String) async {
            messages.append(message)
            await progress(message)
        }

        func openFallbackPage() async {
            await MainActor.run {
                _ = NSWorkspace.shared.open(Self.officialDesktopDownloadURL)
            }
        }

        await record("Preparing ChatGPT Desktop installer.")

        guard await isAppleSiliconMac() else {
            await openFallbackPage()
            await record("Automatic desktop install supports Apple Silicon Macs only. Opened the official ChatGPT download page.")
            return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
        }

        do {
            let workDirectory = fileManager.temporaryDirectory
                .appendingPathComponent("ai-unc-codex-installer-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
            defer {
                try? fileManager.removeItem(at: workDirectory)
            }
            let dmgURL = workDirectory.appendingPathComponent("ChatGPT.dmg")

            await record("Downloading ChatGPT Desktop for Apple Silicon.")
            let download = try await runner.run(
                executable: "/usr/bin/curl",
                arguments: [
                    "--fail",
                    "--location",
                    "--retry", "2",
                    "--output", dmgURL.path,
                    Self.appleSiliconDMGURL.absoluteString
                ]
            )
            guard download.succeeded else {
                await openFallbackPage()
                await record("ChatGPT Desktop download failed. Opened the official download page.")
                return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
            }

            await record("Mounting ChatGPT disk image.")
            let attach = try await runner.run(
                executable: "/usr/bin/hdiutil",
                arguments: ["attach", dmgURL.path, "-nobrowse", "-readonly", "-plist"]
            )
            guard attach.succeeded, let mountPoint = mountPoint(from: attach.standardOutput) else {
                await openFallbackPage()
                await record("ChatGPT disk image could not be mounted. Opened the official download page.")
                return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
            }
            mountedPath = mountPoint

            guard let sourceAppURL = findDesktopApp(in: URL(fileURLWithPath: mountPoint, isDirectory: true)) else {
                await detachDiskImage(at: mountedPath)
                await openFallbackPage()
                await record("ChatGPT.app was not found in the disk image. Opened the official download page.")
                return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
            }

            let targetURL = preferredApplicationsDirectory().appendingPathComponent(sourceAppURL.lastPathComponent, isDirectory: true)
            if let runningApp = await runningDesktopAppDescription() {
                await detachDiskImage(at: mountedPath)
                await record("\(runningApp) is currently open. Quit it, then run Install ChatGPT Desktop again.")
                return CodexInstallResult(installed: false, openedInstallPage: false, messages: messages)
            }

            await record("Installing \(sourceAppURL.lastPathComponent) to \(targetURL.deletingLastPathComponent().path).")
            try await copyAppBundle(from: sourceAppURL, to: targetURL)

            await detachDiskImage(at: mountedPath)
            mountedPath = nil

            await record("ChatGPT Desktop was installed at \(targetURL.path).")
            return CodexInstallResult(installed: true, openedInstallPage: false, messages: messages)
        } catch {
            await detachDiskImage(at: mountedPath)
            await openFallbackPage()
            await record("Automatic desktop install did not complete: \(error.localizedDescription). Opened the official download page.")
            return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func isAppleSiliconMac() async -> Bool {
        guard let result = try? await runner.run(executable: "/usr/bin/uname", arguments: ["-m"]) else {
            return false
        }
        return result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines) == "arm64"
    }

    private func mountPoint(from plistText: String) -> String? {
        guard let data = plistText.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let entities = dictionary["system-entities"] as? [[String: Any]] else {
            return nil
        }

        return entities.compactMap { $0["mount-point"] as? String }.first
    }

    private func findDesktopApp(in mountURL: URL) -> URL? {
        for appBundleName in Self.desktopAppBundleNames {
            let directURL = mountURL.appendingPathComponent(appBundleName, isDirectory: true)
            if fileManager.fileExists(atPath: directURL.path) {
                return directURL
            }
        }

        guard let enumerator = fileManager.enumerator(
            at: mountURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where Self.desktopAppBundleNames.contains(url.lastPathComponent) {
            return url
        }

        return nil
    }

    private func preferredApplicationsDirectory() -> URL {
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if fileManager.isWritableFile(atPath: systemApplications.path) {
            return systemApplications
        }

        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
    }

    private func copyAppBundle(from sourceURL: URL, to targetURL: URL) async throws {
        let parentURL = targetURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)

        let stagingURL = parentURL.appendingPathComponent("\(targetURL.lastPathComponent).installing-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: stagingURL) }

        let copy = try await runner.run(
            executable: "/usr/bin/ditto",
            arguments: [sourceURL.path, stagingURL.path]
        )
        guard copy.succeeded else {
            throw CodexInstallerError.commandFailed(copy.combinedOutput.isEmpty ? "ditto could not copy \(sourceURL.lastPathComponent)." : copy.combinedOutput)
        }

        guard fileManager.fileExists(atPath: targetURL.path) else {
            try fileManager.moveItem(at: stagingURL, to: targetURL)
            return
        }

        let backupURL = parentURL.appendingPathComponent(
            "\(targetURL.lastPathComponent).previous-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.moveItem(at: targetURL, to: backupURL)

        do {
            try fileManager.moveItem(at: stagingURL, to: targetURL)
            try? fileManager.removeItem(at: backupURL)
        } catch {
            do {
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                try fileManager.moveItem(at: backupURL, to: targetURL)
            } catch let rollbackError {
                throw CodexInstallerError.commandFailed(
                    "ChatGPT Desktop replacement failed, and the previous app could not be restored automatically. It remains at \(backupURL.path). \(rollbackError.localizedDescription)"
                )
            }
            throw error
        }
    }

    private func runningDesktopAppDescription() async -> String? {
        await MainActor.run {
            let app = NSWorkspace.shared.runningApplications.first { application in
                if let localizedName = application.localizedName?.lowercased(),
                   localizedName == "chatgpt" || localizedName == "codex" {
                    return true
                }

                if let bundleURL = application.bundleURL,
                   Self.desktopAppBundleNames.contains(bundleURL.lastPathComponent) {
                    return true
                }

                return false
            }

            guard let app else { return nil }
            return app.localizedName ?? app.bundleURL?.lastPathComponent ?? "ChatGPT Desktop"
        }
    }

    private func detachDiskImage(at mountedPath: String?) async {
        guard let mountedPath else { return }
        _ = try? await runner.run(executable: "/usr/bin/hdiutil", arguments: ["detach", mountedPath, "-quiet"])
    }
}
