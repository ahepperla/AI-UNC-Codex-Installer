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
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsURL.appendingPathComponent("Codex", isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Codex", isDirectory: true)
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
}
