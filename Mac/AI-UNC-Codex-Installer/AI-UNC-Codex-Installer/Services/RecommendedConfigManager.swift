import Foundation

enum RecommendedConfigStatus: Equatable, Sendable {
    case upToDate
    case updateAvailable([String])
    case missingConfig

    var title: String {
        switch self {
        case .upToDate:
            return "Up to date"
        case .updateAvailable:
            return "Update available"
        case .missingConfig:
            return "Config missing"
        }
    }
}

final class RecommendedConfigManager: @unchecked Sendable {
    let recommended = RecommendedConfig.uncCodex

    func status(for summary: ConfigSummary) -> RecommendedConfigStatus {
        guard summary.exists else {
            return .missingConfig
        }

        let mismatches = summary.mismatches(from: recommended)
        return mismatches.isEmpty ? .upToDate : .updateAvailable(mismatches)
    }
}
