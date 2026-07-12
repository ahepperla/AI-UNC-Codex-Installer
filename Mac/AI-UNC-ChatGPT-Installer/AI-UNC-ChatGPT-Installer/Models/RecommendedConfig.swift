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

struct CodexModel: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var label: String
    var deploymentLocality: String
    var apiAvailability: String
    var isRecommended: Bool = false
    var supportedReasoningEfforts: [CodexReasoningEffort] = []
    var defaultReasoningEffort: CodexReasoningEffort?

    var displayLabel: String {
        isRecommended ? "\(label) Recommended" : label
    }

    var supportsReasoningSelection: Bool {
        !supportedReasoningEfforts.isEmpty
    }

    var reasoningHelpText: String {
        if supportsReasoningSelection {
            return "Choose how much time Codex spends thinking for this model."
        }
        return "Uses the model default. This avoids writing an unsupported reasoning option."
    }

    static let recommended = CodexModel(
        id: "gpt-5.5",
        label: "gpt-5.5",
        deploymentLocality: "US Data Zone",
        apiAvailability: "pre-v1, v1",
        isRecommended: true,
        supportedReasoningEfforts: CodexReasoningEffort.allCases,
        defaultReasoningEffort: .medium
    )

    static let approvedCodexModels: [CodexModel] = [
        .recommended,
        CodexModel(id: "gpt-5.4", label: "gpt-5.4", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-5.4-mini", label: "gpt-5.4-mini", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-5.4-nano", label: "gpt-5.4-nano", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-5.3-codex", label: "gpt-5.3-codex", deploymentLocality: "US Data Zone", apiAvailability: "v1"),
        CodexModel(id: "gpt-5.2", label: "gpt-5.2", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-5.1", label: "gpt-5.1", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-5", label: "gpt-5", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-5-mini", label: "gpt-5-mini", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-5-nano", label: "gpt-5-nano", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-4.1", label: "gpt-4.1", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-4.1-mini", label: "gpt-4.1-mini", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-4.1-nano", label: "gpt-4.1-nano", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-4o", label: "gpt-4o", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "gpt-4o-mini", label: "gpt-4o-mini", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "o1", label: "o1", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "o1-preview", label: "o1-preview", deploymentLocality: "regional", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "o1-mini", label: "o1-mini", deploymentLocality: "regional", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "o3-mini", label: "o3-mini", deploymentLocality: "US Data Zone", apiAvailability: "pre-v1, v1"),
        CodexModel(id: "chat", label: "chat (gpt-4.1-mini)", deploymentLocality: "regional", apiAvailability: "pre-v1, v1")
    ]

    static func approvedModel(id: String?) -> CodexModel? {
        guard let id else { return nil }
        return approvedCodexModels.first { $0.id == id }
    }
}

struct RecommendedConfig: Codable, Equatable, Sendable {
    var recommendedModel: String
    var recommendedProvider: String
    var reasoningEffort: CodexReasoningEffort?
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
        recommendedModel: CodexModel.recommended.id,
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
        guard let approvedModel = CodexModel.approvedModel(id: model) else {
            mismatches.append("Model is \(model ?? "missing"), expected an approved UNC Codex model.")
            return mismatches
        }
        if !approvedModel.isRecommended {
            // Approved alternatives are valid; keep the dashboard quiet for intentional choices.
        }
        if provider != recommended.recommendedProvider {
            mismatches.append("Provider is \(provider ?? "missing"), expected \(recommended.recommendedProvider).")
        }
        if let reasoningEffort {
            if CodexReasoningEffort(rawValue: reasoningEffort) == nil {
                let validValues = CodexReasoningEffort.allCases.map(\.rawValue).joined(separator: ", ")
                mismatches.append("Reasoning effort is \(reasoningEffort), expected one of \(validValues).")
            } else if !approvedModel.supportedReasoningEfforts.isEmpty,
                      let parsedEffort = CodexReasoningEffort(rawValue: reasoningEffort),
                      !approvedModel.supportedReasoningEfforts.contains(parsedEffort) {
                let validValues = approvedModel.supportedReasoningEfforts.map(\.rawValue).joined(separator: ", ")
                mismatches.append("Reasoning effort is \(reasoningEffort), expected one of \(validValues) for \(approvedModel.id).")
            } else if approvedModel.supportedReasoningEfforts.isEmpty {
                mismatches.append("Reasoning effort is set for \(approvedModel.id), which should use the model default.")
            }
        } else if approvedModel.isRecommended {
            mismatches.append("Reasoning effort is missing for \(approvedModel.id).")
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
