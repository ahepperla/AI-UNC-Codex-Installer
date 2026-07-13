import AppKit
import Foundation

@MainActor
final class AppCleanupManager: @unchecked Sendable {
    func moveCurrentAppToTrashIfPossible() async -> AppCleanupResult {
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            return .notMoved("The installer is not running from a normal .app bundle.")
        }

        return await moveToTrash(appURL)
    }

    func moveToTrash(_ url: URL) async -> AppCleanupResult {
        await withCheckedContinuation { (continuation: CheckedContinuation<AppCleanupResult, Never>) in
            NSWorkspace.shared.recycle([url]) { _, error in
                if let error {
                    continuation.resume(returning: .notMoved(error.localizedDescription))
                } else {
                    continuation.resume(returning: .movedToTrash)
                }
            }
        }
    }
}

enum AppCleanupResult {
    case movedToTrash
    case notMoved(String)
}
