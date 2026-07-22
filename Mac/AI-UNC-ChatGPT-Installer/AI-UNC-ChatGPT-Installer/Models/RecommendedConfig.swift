import Foundation

enum CodexReasoningEffort: String, CaseIterable, Identifiable, Codable, Sendable {
    case low
    case medium
    case high
    case xhigh
    case max
    case ultra

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .xhigh:
            return "Extra High"
        case .max:
            return "Max"
        case .ultra:
            return "Ultra"
        }
    }

    var helpText: String {
        switch self {
        case .low:
            return "Faster responses for straightforward tasks, with less time spent reasoning."
        case .medium:
            return "Recommended balance of speed and careful reasoning for most work."
        case .high:
            return "More careful reasoning for complex code changes and troubleshooting."
        case .xhigh:
            return "Deep reasoning for difficult tasks; responses may take longer."
        case .max:
            return "Maximum supported reasoning for the hardest tasks; expect the longest waits."
        case .ultra:
            return "Maximum reasoning with automatic task delegation for large, multi-step work."
        }
    }

    var catalogDescription: String {
        switch self {
        case .low:
            return "Faster responses with lighter reasoning for straightforward tasks"
        case .medium:
            return "Recommended balance of speed and reasoning depth for most work"
        case .high:
            return "More careful reasoning for complex code changes and troubleshooting"
        case .xhigh:
            return "Deep reasoning for difficult tasks, with longer response times"
        case .max:
            return "Maximum supported reasoning for the hardest tasks"
        case .ultra:
            return "Maximum reasoning with automatic task delegation for large, multi-step work"
        }
    }
}

struct CodexModel: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var label: String
    var deploymentLocality: String
    var apiAvailability: String
    var modelHelpText: String = "Approved compatibility model for workflows that require it."
    var isRecommended: Bool = false
    var supportedReasoningEfforts: [CodexReasoningEffort] = []
    var defaultReasoningEffort: CodexReasoningEffort?

    var displayLabel: String {
        label
    }

    var supportsReasoningSelection: Bool {
        !selectableReasoningEfforts.isEmpty
    }

    var selectableReasoningEfforts: [CodexReasoningEffort] {
        supportedReasoningEfforts.filter { $0 != .max }
    }

    var catalogReasoningLevels: [[String: String]] {
        supportedReasoningEfforts.map { effort in
            [
                "effort": effort.rawValue,
                "description": effort.catalogDescription
            ]
        }
    }

    var reasoningHelpText: String {
        if supportsReasoningSelection {
            return "Choose how much time Codex spends reasoning before it responds."
        }
        return "Uses the model default because verified reasoning choices are not available for this model."
    }

    static let recommended = CodexModel(
        id: "gpt-5.6-sol",
        label: "gpt-5.6-sol",
        deploymentLocality: "US Data Zone",
        apiAvailability: "pre-v1, v1",
        modelHelpText: "Recommended default and latest frontier model for complex coding and long-running work.",
        isRecommended: true,
        supportedReasoningEfforts: [.low, .medium, .high, .xhigh, .max, .ultra],
        defaultReasoningEffort: .medium
    )

    static let approvedCodexModels: [CodexModel] = [
        .recommended,
        CodexModel(
            id: "gpt-5.6-terra",
            label: "gpt-5.6-terra",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Balanced model for everyday coding, debugging, and general work.",
            supportedReasoningEfforts: [.low, .medium, .high, .xhigh, .max, .ultra],
            defaultReasoningEffort: .medium
        ),
        CodexModel(
            id: "gpt-5.6-luna",
            label: "gpt-5.6-luna",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Fast, lightweight model for shorter coding tasks and quick edits.",
            supportedReasoningEfforts: [.low, .medium, .high, .xhigh, .max],
            defaultReasoningEffort: .medium
        ),
        CodexModel(
            id: "gpt-5.5",
            label: "gpt-5.5",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Frontier model for complex coding, research, and real-world work.",
            supportedReasoningEfforts: [.low, .medium, .high, .xhigh],
            defaultReasoningEffort: .medium
        ),
        CodexModel(
            id: "gpt-5.4",
            label: "gpt-5.4",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Strong model for everyday coding and debugging.",
            supportedReasoningEfforts: [.low, .medium, .high, .xhigh],
            defaultReasoningEffort: .medium
        ),
        CodexModel(
            id: "gpt-5.4-mini",
            label: "gpt-5.4-mini",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Fast, lightweight model for straightforward coding tasks.",
            supportedReasoningEfforts: [.low, .medium, .high, .xhigh],
            defaultReasoningEffort: .medium
        ),
        CodexModel(
            id: "gpt-5.4-nano",
            label: "gpt-5.4-nano",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Small approved model for simple tasks and compatibility."
        ),
        CodexModel(
            id: "gpt-5.3-codex",
            label: "gpt-5.3-codex",
            deploymentLocality: "US Data Zone",
            apiAvailability: "v1",
            modelHelpText: "Coding-focused model for software development workflows.",
            supportedReasoningEfforts: [.low, .medium, .high, .xhigh],
            defaultReasoningEffort: .medium
        ),
        CodexModel(
            id: "gpt-5.2",
            label: "gpt-5.2",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Model for professional work and long-running agent tasks.",
            supportedReasoningEfforts: [.low, .medium, .high, .xhigh],
            defaultReasoningEffort: .medium
        ),
        CodexModel(
            id: "gpt-5.1",
            label: "gpt-5.1",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier general-purpose GPT-5 model for existing workflows."
        ),
        CodexModel(
            id: "gpt-5",
            label: "gpt-5",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier GPT-5 model for general work and compatibility."
        ),
        CodexModel(
            id: "gpt-5-mini",
            label: "gpt-5-mini",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier lightweight GPT-5 model for simple, quick tasks."
        ),
        CodexModel(
            id: "gpt-5-nano",
            label: "gpt-5-nano",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Small earlier GPT-5 model for basic, low-complexity tasks."
        ),
        CodexModel(
            id: "gpt-4.1",
            label: "gpt-4.1",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier general-purpose model for coding and instruction-following tasks."
        ),
        CodexModel(
            id: "gpt-4.1-mini",
            label: "gpt-4.1-mini",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier lightweight general-purpose model for shorter tasks."
        ),
        CodexModel(
            id: "gpt-4.1-nano",
            label: "gpt-4.1-nano",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Small earlier model for basic, low-complexity tasks."
        ),
        CodexModel(
            id: "gpt-4o",
            label: "gpt-4o",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier general-purpose model for text, coding, and multimodal workflows."
        ),
        CodexModel(
            id: "gpt-4o-mini",
            label: "gpt-4o-mini",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier lightweight model for shorter text and multimodal tasks."
        ),
        CodexModel(
            id: "o1",
            label: "o1",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier deep-reasoning model for complex problems; uses model-default effort."
        ),
        CodexModel(
            id: "o1-preview",
            label: "o1-preview",
            deploymentLocality: "regional",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Preview-era deep-reasoning model for compatibility with existing workflows."
        ),
        CodexModel(
            id: "o1-mini",
            label: "o1-mini",
            deploymentLocality: "regional",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier compact reasoning model for focused problems; uses model-default effort."
        ),
        CodexModel(
            id: "o3-mini",
            label: "o3-mini",
            deploymentLocality: "US Data Zone",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Earlier compact reasoning model for coding, math, and logic tasks."
        ),
        CodexModel(
            id: "chat",
            label: "chat (gpt-4.1-mini)",
            deploymentLocality: "regional",
            apiAvailability: "pre-v1, v1",
            modelHelpText: "Compatibility alias for the gpt-4.1-mini chat deployment."
        )
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
    var modelCatalogPath: String?
    var modelCatalogExists: Bool
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
            modelCatalogPath: nil,
            modelCatalogExists: false,
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
        } else if approvedModel.supportsReasoningSelection {
            mismatches.append("Reasoning effort is missing for \(approvedModel.id).")
        }
        if modelCatalogPath == nil {
            mismatches.append("UNC model catalog is missing; Codex may show unapproved OpenAI models.")
        } else if !modelCatalogExists {
            mismatches.append("UNC model catalog file is missing at \(modelCatalogPath ?? "configured path").")
        }
        if endpoint != recommended.endpoint {
            mismatches.append("Endpoint is \(endpoint ?? "missing"), expected \(recommended.endpoint).")
        }
        if wireAPI != recommended.wireAPI {
            mismatches.append("Wire API is \(wireAPI ?? "missing"), expected \(recommended.wireAPI).")
        }
        switch (usesEnvironmentKey, usesPlaintextBearerToken) {
        case (true, false), (false, true):
            break
        case (false, false):
            mismatches.append("Authentication is missing; configure either \(KeychainManager.serviceName) or a plaintext bearer token.")
        case (true, true):
            mismatches.append("Both environment-key and plaintext authentication are configured; choose one.")
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
