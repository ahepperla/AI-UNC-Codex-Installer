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
            return "Codex.app was not found in the mounted disk image at \(path)."
        }
    }
}

final class CodexInstaller: @unchecked Sendable {
    static let officialInstallURL = URL(string: "https://openai.com/codex/")!
    static let appleSiliconDMGURL = URL(string: "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg")!

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

        await record("Checking for Homebrew.")
        if let brew = await findExecutable(named: "brew", commonPaths: ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]) {
            await record("Homebrew found at \(brew). Attempting: brew install --cask codex")
            do {
                let result = try await runner.run(executable: brew, arguments: ["install", "--cask", "codex"])
                if result.succeeded {
                    await record("Homebrew reported a successful Codex installation.")
                    return CodexInstallResult(installed: true, openedInstallPage: false, messages: messages)
                }
                await record("Homebrew install failed:\n\(result.combinedOutput)")
            } catch {
                await record("Homebrew install could not run: \(error.localizedDescription)")
            }
        } else {
            await record("Homebrew was not found in common macOS locations.")
        }

        await record("Checking for npm fallback.")
        if let npm = await findExecutable(named: "npm", commonPaths: ["/opt/homebrew/bin/npm", "/usr/local/bin/npm", "/usr/bin/npm"]) {
            await record("npm found at \(npm). Checking whether @openai/codex is available.")
            do {
                let viewResult = try await runner.run(executable: npm, arguments: ["view", "@openai/codex", "version"])
                if viewResult.succeeded {
                    await record("@openai/codex is available through npm. Attempting global install.")
                    let installResult = try await runner.run(executable: npm, arguments: ["install", "-g", "@openai/codex"])
                    if installResult.succeeded {
                        await record("npm reported a successful Codex CLI installation.")
                        return CodexInstallResult(installed: true, openedInstallPage: false, messages: messages)
                    }
                    await record("npm install failed:\n\(installResult.combinedOutput)")
                } else {
                    await record("npm could not confirm @openai/codex availability:\n\(viewResult.combinedOutput)")
                }
            } catch {
                await record("npm fallback could not run: \(error.localizedDescription)")
            }
        } else {
            await record("npm was not found in common macOS locations.")
        }

        if openDownloadPageOnFailure {
            await MainActor.run {
                _ = NSWorkspace.shared.open(Self.officialInstallURL)
            }
            await record("Automatic installation did not complete. Opened the official Codex page.")
        } else {
            await record("Automatic CLI installation did not complete. Use Install Desktop App if you prefer the macOS desktop app.")
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
                _ = NSWorkspace.shared.open(Self.officialInstallURL)
            }
        }

        await record("Preparing Codex Desktop installer.")

        guard await isAppleSiliconMac() else {
            await openFallbackPage()
            await record("Automatic desktop install supports Apple Silicon Macs only. Opened the official Codex page.")
            return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
        }

        do {
            let workDirectory = fileManager.temporaryDirectory
                .appendingPathComponent("ai-unc-codex-installer-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
            defer {
                try? fileManager.removeItem(at: workDirectory)
            }
            let dmgURL = workDirectory.appendingPathComponent("Codex.dmg")

            await record("Downloading Codex Desktop for Apple Silicon.")
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
                await record("Codex Desktop download failed. Opened the official Codex page.")
                return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
            }

            await record("Mounting Codex disk image.")
            let attach = try await runner.run(
                executable: "/usr/bin/hdiutil",
                arguments: ["attach", dmgURL.path, "-nobrowse", "-readonly", "-plist"]
            )
            guard attach.succeeded, let mountPoint = mountPoint(from: attach.standardOutput) else {
                await openFallbackPage()
                await record("Codex disk image could not be mounted. Opened the official Codex page.")
                return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
            }
            mountedPath = mountPoint

            guard let sourceAppURL = findCodexApp(in: URL(fileURLWithPath: mountPoint, isDirectory: true)) else {
                await detachDiskImage(at: mountedPath)
                await openFallbackPage()
                await record("Codex.app was not found in the disk image. Opened the official Codex page.")
                return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
            }

            let targetURL = preferredApplicationsDirectory().appendingPathComponent("Codex.app", isDirectory: true)
            await record("Installing Codex Desktop to \(targetURL.deletingLastPathComponent().path).")
            try await copyAppBundle(from: sourceAppURL, to: targetURL)

            await detachDiskImage(at: mountedPath)
            mountedPath = nil

            await record("Codex Desktop was installed at \(targetURL.path).")
            return CodexInstallResult(installed: true, openedInstallPage: false, messages: messages)
        } catch {
            await detachDiskImage(at: mountedPath)
            await openFallbackPage()
            await record("Automatic desktop install did not complete: \(error.localizedDescription). Opened the official Codex page.")
            return CodexInstallResult(installed: false, openedInstallPage: true, messages: messages)
        }
    }

    private func findExecutable(named name: String, commonPaths: [String]) async -> String? {
        if let path = commonPaths.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return path
        }

        guard fileManager.isExecutableFile(atPath: "/usr/bin/which") else {
            return nil
        }

        guard let result = try? await runner.run(executable: "/usr/bin/which", arguments: [name]) else {
            return nil
        }
        let path = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.succeeded && fileManager.isExecutableFile(atPath: path) ? path : nil
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

    private func findCodexApp(in mountURL: URL) -> URL? {
        let directURL = mountURL.appendingPathComponent("Codex.app", isDirectory: true)
        if fileManager.fileExists(atPath: directURL.path) {
            return directURL
        }

        guard let enumerator = fileManager.enumerator(
            at: mountURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == "Codex.app" {
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

        let stagingURL = parentURL.appendingPathComponent("Codex.app.installing-\(UUID().uuidString)", isDirectory: true)
        if fileManager.fileExists(atPath: stagingURL.path) {
            try fileManager.removeItem(at: stagingURL)
        }

        let copy = try await runner.run(
            executable: "/usr/bin/ditto",
            arguments: [sourceURL.path, stagingURL.path]
        )
        guard copy.succeeded else {
            throw CodexInstallerError.commandFailed(copy.combinedOutput.isEmpty ? "ditto could not copy Codex.app." : copy.combinedOutput)
        }

        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.moveItem(at: stagingURL, to: targetURL)
    }

    private func detachDiskImage(at mountedPath: String?) async {
        guard let mountedPath else { return }
        _ = try? await runner.run(executable: "/usr/bin/hdiutil", arguments: ["detach", mountedPath, "-quiet"])
    }
}
