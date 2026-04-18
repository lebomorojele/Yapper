import Foundation

enum LLMError: Error, LocalizedError, Sendable {
    case invalidResponse
    case networkError
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from LLM"
        case .networkError: return "Network error"
        case .noAPIKey: return "No OpenAI API key configured"
        }
    }
}

final class LLMProcessor: @unchecked Sendable {

    /// Process text through an LLM using the selected smart-mode option.
    /// Falls back to raw text if no API key is configured.
    func process(text: String, option: SmartModeOption) async throws -> String {
        guard option != .cancel else { return text }

        let template = option.promptTemplate
        guard !template.isEmpty else { return text }

        let prompt = template.replacingOccurrences(of: "{input}", with: text)

        let settings = SettingsManager.shared.settings
        let apiKey = settings.openAIAPIKey
            ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]

        guard let apiKey, !apiKey.isEmpty else {
            print("[LLM] No API key — returning raw text")
            return text
        }

        return try await callOpenAI(prompt: prompt, apiKey: apiKey, model: settings.llmModel)
    }

    // MARK: - OpenAI API

    private func callOpenAI(prompt: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw LLMError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 1000,
            "temperature": 0.3,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw LLMError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
