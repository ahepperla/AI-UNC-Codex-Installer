import Foundation

final class WorkspaceManager: @unchecked Sendable {
    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let workspacePathKey = "codexWorkspacePath"

    init(fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.defaults = defaults
    }

    var defaultWorkspaceURL: URL {
        if isExistingDirectory(legacyCodexWorkspaceURL) {
            return legacyCodexWorkspaceURL
        }

        return preferredChatGPTWorkspaceURL
    }

    var preferredChatGPTWorkspaceURL: URL {
        documentsDirectoryURL.appendingPathComponent("ChatGPT", isDirectory: true)
    }

    var legacyCodexWorkspaceURL: URL {
        documentsDirectoryURL.appendingPathComponent("Codex", isDirectory: true)
    }

    private var documentsDirectoryURL: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        return documentsURL.standardizedFileURL
    }

    var workspaceURL: URL {
        guard let path = defaults.string(forKey: workspacePathKey),
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultWorkspaceURL
        }

        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
    }

    func setWorkspaceURL(_ url: URL) {
        defaults.set(url.standardizedFileURL.path, forKey: workspacePathKey)
    }

    func resetToDefault() {
        defaults.removeObject(forKey: workspacePathKey)
    }

    func ensureWorkspaceDirectory() throws -> URL {
        let url = workspaceURL.standardizedFileURL
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func isLegacyCodexWorkspace(_ url: URL) -> Bool {
        url.standardizedFileURL.path == legacyCodexWorkspaceURL.standardizedFileURL.path
    }

    private func isExistingDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
