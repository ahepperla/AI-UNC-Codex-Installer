import AppKit
import Foundation

@MainActor
final class SupportReportManager: @unchecked Sendable {
    func openMail(report: String) throws {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = ""
        components.queryItems = [
            URLQueryItem(name: "subject", value: "AI @ UNC Codex Installer Support Report"),
            URLQueryItem(name: "body", value: report)
        ]

        guard let url = components.url else {
            throw SupportReportError.invalidMailURL
        }

        NSWorkspace.shared.open(url)
    }
}

enum SupportReportError: LocalizedError {
    case invalidMailURL

    var errorDescription: String? {
        switch self {
        case .invalidMailURL:
            return "AI @ UNC Codex Installer could not create a Mail message URL."
        }
    }
}
