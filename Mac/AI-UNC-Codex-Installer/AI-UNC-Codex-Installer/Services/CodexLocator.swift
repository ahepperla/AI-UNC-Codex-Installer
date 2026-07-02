import Foundation

struct CodexInstallation: Equatable, Sendable {
    var cliPath: String?
    var desktopAppPath: String?
    var version: String?

    var isCLIInstalled: Bool {
        cliPath != nil
    }

    var canLaunchCLI: Bool {
        isCLIInstalled
    }

    var isDesktopInstalled: Bool {
        desktopAppPath != nil
    }

    var isInstalled: Bool {
        isCLIInstalled || isDesktopInstalled
    }
}

final class CodexLocator: @unchecked Sendable {
    private let runner: ProcessRunner
    private let fileManager: FileManager

    init(runner: ProcessRunner = ProcessRunner(), fileManager: FileManager = .default) {
        self.runner = runner
        self.fileManager = fileManager
    }

    func detectInstallation() async -> CodexInstallation {
        let cliPath = await findCLIPath()
        let appPath = await findDesktopAppPath()
        let version = await findVersion(cliPath: cliPath, desktopAppPath: appPath)

        return CodexInstallation(
            cliPath: cliPath,
            desktopAppPath: appPath,
            version: version
        )
    }

    private func findCLIPath() async -> String? {
        let commonPaths = [
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            "\(NSHomeDirectory())/.local/bin/codex"
        ]

        if let path = commonPaths.first(where: { isUsableCLIPath($0) }) {
            return path
        }

        if let path = await findCLIPathFromLoginShell() {
            return path
        }

        guard fileManager.isExecutableFile(atPath: "/usr/bin/which") else {
            return nil
        }

        do {
            let result = try await runner.run(executable: "/usr/bin/which", arguments: ["codex"])
            let path = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.succeeded && isUsableCLIPath(path) ? path : nil
        } catch {
            return nil
        }
    }

    private func findCLIPathFromLoginShell() async -> String? {
        guard fileManager.isExecutableFile(atPath: "/bin/zsh") else {
            return nil
        }

        do {
            let result = try await runner.run(executable: "/bin/zsh", arguments: ["-lc", "command -v codex"])
            let path = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.succeeded && isUsableCLIPath(path) ? path : nil
        } catch {
            return nil
        }
    }

    private func isUsableCLIPath(_ path: String) -> Bool {
        guard !path.isEmpty, fileManager.isExecutableFile(atPath: path) else {
            return false
        }

        return !isDesktopBundledCLIPath(path)
    }

    private func isDesktopBundledCLIPath(_ path: String) -> Bool {
        let rawPath = path.lowercased()
        let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path.lowercased()
        return [rawPath, resolvedPath].contains { candidate in
            candidate.contains(".app/contents/resources/codex")
        }
    }

    private func findDesktopAppPath() async -> String? {
        let applicationDirectories = [
            "/Applications",
            "\(NSHomeDirectory())/Applications"
        ]

        for directory in applicationDirectories {
            let canonicalPath = "\(directory)/Codex.app"
            if fileManager.fileExists(atPath: canonicalPath) {
                return canonicalPath
            }

            guard let applications = try? fileManager.contentsOfDirectory(atPath: directory) else {
                continue
            }

            if let appPath = applications
                .filter({ $0.localizedCaseInsensitiveCompare("Codex.app") == .orderedSame })
                .map({ "\(directory)/\($0)" })
                .first(where: { fileManager.fileExists(atPath: $0) }) {
                return appPath
            }
        }

        guard fileManager.isExecutableFile(atPath: "/usr/bin/mdfind") else {
            return nil
        }

        guard let result = try? await runner.run(
            executable: "/usr/bin/mdfind",
            arguments: ["kMDItemFSName == 'Codex.app'c"]
        ), result.succeeded else {
            return nil
        }

        return result.standardOutput
            .split(separator: "\n")
            .map(String.init)
            .first(where: { fileManager.fileExists(atPath: $0) })
    }

    private func findVersion(cliPath: String?, desktopAppPath: String?) async -> String? {
        if let cliPath {
            for arguments in [["--version"], ["version"], ["-V"]] {
                do {
                    let result = try await runner.run(executable: cliPath, arguments: arguments)
                    let text = result.combinedOutput
                        .split(separator: "\n")
                        .map(String.init)
                        .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                    if result.succeeded, let text {
                        return text
                    }
                } catch {
                    continue
                }
            }
        }

        if let desktopAppPath {
            let infoURL = URL(fileURLWithPath: desktopAppPath)
                .appendingPathComponent("Contents")
                .appendingPathComponent("Info.plist")
            if let bundle = Bundle(url: URL(fileURLWithPath: desktopAppPath)),
               let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                return "Codex Desktop \(version)"
            }
            if let dictionary = NSDictionary(contentsOf: infoURL),
               let version = dictionary["CFBundleShortVersionString"] as? String {
                return "Codex Desktop \(version)"
            }
        }

        return nil
    }
}
