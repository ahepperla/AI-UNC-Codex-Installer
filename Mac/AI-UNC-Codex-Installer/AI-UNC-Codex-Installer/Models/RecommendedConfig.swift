import Foundation

enum CodexReasoningEffort: String, CaseIterable, Identifiable, Codable, Sendable {
    case minimal
    case low
    case medium
    case high
    case xhigh

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .xhigh:
            return "Extra High"
        }
    }

    var helpText: String {
        switch self {
        case .minimal:
            return "Fastest responses for very small edits."
        case .low:
            return "Faster responses for straightforward tasks."
        case .medium:
            return "Balanced default for most UNC Codex work."
        case .high:
            return "More careful reasoning for complex changes."
        case .xhigh:
            return "Most thorough reasoning, with slower responses."
        }
    }
}

struct RecommendedConfig: Codable, Equatable, Sendable {
    var recommendedModel: String
    var recommendedProvider: String
    var reasoningEffort: CodexReasoningEffort
    var endpoint: String
    var wireAPI: String

    enum CodingKeys: String, CodingKey {
        case recommendedModel = "recommended_model"
        case recommendedProvider = "recommended_provider"
        case reasoningEffort = "reasoning_effort"
        case endpoint
        case wireAPI = "wire_api"
    }

    static let uncCodex = RecommendedConfig(
        recommendedModel: "gpt-5.5",
        recommendedProvider: "azure",
        reasoningEffort: .medium,
        endpoint: "https://azureaiapi.cloud.unc.edu/openai/v1",
        wireAPI: "responses"
    )
}

struct ConfigSummary: Equatable, Sendable {
    var exists: Bool
    var path: String
    var model: String?
    var provider: String?
    var reasoningEffort: String?
    var endpoint: String?
    var wireAPI: String?
    var usesEnvironmentKey: Bool
    var usesPlaintextBearerToken: Bool

    static func missing(path: String) -> ConfigSummary {
        ConfigSummary(
            exists: false,
            path: path,
            model: nil,
            provider: nil,
            reasoningEffort: nil,
            endpoint: nil,
            wireAPI: nil,
            usesEnvironmentKey: false,
            usesPlaintextBearerToken: false
        )
    }

    func mismatches(from recommended: RecommendedConfig) -> [String] {
        var mismatches: [String] = []
        if model != recommended.recommendedModel {
            mismatches.append("Model is \(model ?? "missing"), expected \(recommended.recommendedModel).")
        }
        if provider != recommended.recommendedProvider {
            mismatches.append("Provider is \(provider ?? "missing"), expected \(recommended.recommendedProvider).")
        }
        if let reasoningEffort {
            if CodexReasoningEffort(rawValue: reasoningEffort) == nil {
                let validValues = CodexReasoningEffort.allCases.map(\.rawValue).joined(separator: ", ")
                mismatches.append("Reasoning effort is \(reasoningEffort), expected one of \(validValues).")
            }
        } else {
            mismatches.append("Reasoning effort is missing.")
        }
        if endpoint != recommended.endpoint {
            mismatches.append("Endpoint is \(endpoint ?? "missing"), expected \(recommended.endpoint).")
        }
        if wireAPI != recommended.wireAPI {
            mismatches.append("Wire API is \(wireAPI ?? "missing"), expected \(recommended.wireAPI).")
        }
        return mismatches
    }
}

enum APIKeyStorageMode: String, CaseIterable, Identifiable, Sendable {
    case keychain
    case plaintextConfig

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keychain:
            return "Store in Keychain"
        case .plaintextConfig:
            return "Store in config.toml"
        }
    }
}
