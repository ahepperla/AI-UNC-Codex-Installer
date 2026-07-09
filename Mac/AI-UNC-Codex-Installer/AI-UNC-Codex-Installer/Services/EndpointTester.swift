import Foundation

struct ConnectionTestResult: Identifiable, Equatable, Sendable {
    var id = UUID()
    var success: Bool
    var message: String
    var testedAt: Date
    var httpStatus: Int?
    var responseSnippet: String?
}

final class EndpointTester: @unchecked Sendable {
    let endpointURL = URL(string: "https://azureaiapi.cloud.unc.edu/openai/v1/responses")!

    func test(apiKey: String?, model: String = RecommendedConfig.uncCodex.recommendedModel) async -> ConnectionTestResult {
        guard let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ConnectionTestResult(
                success: false,
                message: "No API key is available for the connection test.",
                testedAt: Date(),
                httpStatus: nil,
                responseSnippet: nil
            )
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "input": "Reply exactly: UNC Codex setup OK",
            "store": false,
            "background": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let responseText = String(data: data, encoding: .utf8) ?? ""
            let snippet = Self.snippet(from: responseText)

            guard let statusCode else {
                return ConnectionTestResult(
                    success: false,
                    message: "The endpoint did not return an HTTP response.",
                    testedAt: Date(),
                    httpStatus: nil,
                    responseSnippet: snippet
                )
            }

            guard (200..<300).contains(statusCode) else {
                return ConnectionTestResult(
                    success: false,
                    message: Self.httpErrorMessage(statusCode: statusCode),
                    testedAt: Date(),
                    httpStatus: statusCode,
                    responseSnippet: snippet
                )
            }

            guard responseText.contains("UNC Codex setup OK") else {
                return ConnectionTestResult(
                    success: false,
                    message: "The endpoint responded, but the model response did not contain the expected confirmation text.",
                    testedAt: Date(),
                    httpStatus: statusCode,
                    responseSnippet: snippet
                )
            }

            return ConnectionTestResult(
                success: true,
                message: "Connection test succeeded.",
                testedAt: Date(),
                httpStatus: statusCode,
                responseSnippet: snippet
            )
        } catch {
            return ConnectionTestResult(
                success: false,
                message: "Connection test failed: \(error.localizedDescription)",
                testedAt: Date(),
                httpStatus: nil,
                responseSnippet: nil
            )
        }
    }

    private static func httpErrorMessage(statusCode: Int) -> String {
        switch statusCode {
        case 401, 403:
            return "Authentication failed. Check that the UNC Azure OpenAI API key is valid."
        case 404:
            return "Endpoint or model was not found. Check the UNC endpoint and model deployment."
        case 429:
            return "The endpoint rate limit was reached. Try again later."
        case 500..<600:
            return "The UNC Azure OpenAI endpoint returned a server error."
        default:
            return "The endpoint returned HTTP \(statusCode)."
        }
    }

    private static func snippet(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(1000))
    }
}
