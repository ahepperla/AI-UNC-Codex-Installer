import Foundation

final class WorkspaceManager: @unchecked Sendable {
    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let workspacePathKey = "codexWorkspacePath"

    init(fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.defaults = defaults
        migrateStaleChildWorkspace()
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

        let savedURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
        let normalizedURL = normalizedWorkspaceURL(savedURL)
        if normalizedURL.path != savedURL.standardizedFileURL.path {
            defaults.set(normalizedURL.path, forKey: workspacePathKey)
            removeStaleEmptyChildWorkspace()
        }
        return normalizedURL
    }

    func setWorkspaceURL(_ url: URL) {
        defaults.set(normalizedWorkspaceURL(url).path, forKey: workspacePathKey)
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
        let workspacePath = url.standardizedFileURL.path
        let legacyPath = legacyCodexWorkspaceURL.standardizedFileURL.path
        return workspacePath == legacyPath || url.standardizedFileURL.deletingLastPathComponent().path == legacyPath
    }

    private func isExistingDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func normalizedWorkspaceURL(_ url: URL) -> URL {
        let standardizedURL = url.standardizedFileURL
        let oldChildDefaultURL = legacyCodexWorkspaceURL.appendingPathComponent("ChatGPT", isDirectory: true).standardizedFileURL

        if standardizedURL.path == oldChildDefaultURL.path {
            return legacyCodexWorkspaceURL.standardizedFileURL
        }

        return standardizedURL
    }

    private func migrateStaleChildWorkspace() {
        if let path = defaults.string(forKey: workspacePathKey),
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let savedURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
            let normalizedURL = normalizedWorkspaceURL(savedURL)
            if normalizedURL.path != savedURL.standardizedFileURL.path {
                defaults.set(normalizedURL.path, forKey: workspacePathKey)
            }
        }

        removeStaleEmptyChildWorkspace()
    }

    private func removeStaleEmptyChildWorkspace() {
        let url = legacyCodexWorkspaceURL.appendingPathComponent("ChatGPT", isDirectory: true).standardizedFileURL
        guard isExistingDirectory(url),
              (try? fileManager.contentsOfDirectory(atPath: url.path).isEmpty) == true else {
            return
        }

        try? fileManager.removeItem(at: url)
    }
}
