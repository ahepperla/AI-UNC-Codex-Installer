import Foundation

enum DiagnosticSeverity: String, Codable, CaseIterable, Sendable {
    case pass = "Pass"
    case warning = "Warning"
    case fail = "Fail"
}

struct DiagnosticResult: Identifiable, Codable, Sendable {
    var id = UUID()
    var name: String
    var severity: DiagnosticSeverity
    var detail: String
}

struct DiagnosticReport: Sendable {
    var generatedAt: Date
    var results: [DiagnosticResult]

    var plainText: String {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = [
            "AI @ UNC Codex Installer Diagnostic Report",
            "Generated: \(formatter.string(from: generatedAt))",
            ""
        ]

        for result in results {
            lines.append("[\(result.severity.rawValue)] \(result.name)")
            lines.append(result.detail)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
