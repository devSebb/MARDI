import Foundation

/// Hits openrouter.ai — a single API that proxies hundreds of models using the
/// OpenAI chat completions schema. Handy for trying Claude, GPT-5, Gemini,
/// Llama, etc. from the same app without juggling multiple keys.
final class OpenRouterProvider: LLMProvider {
    let apiKey: String
    let model: String

    var displayName: String { "OpenRouter · \(model)" }

    init(apiKey: String, model: String = "anthropic/claude-haiku-4.5") {
        self.apiKey = apiKey
        self.model = model
    }

    func tagAndTitle(_ memory: Memory) async throws -> TagResult {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }

        var req = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 25
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("https://github.com/", forHTTPHeaderField: "HTTP-Referer")
        req.addValue("MARDI", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [
                ["role": "system", "content": TaggingPrompt.system],
                ["role": "user", "content": TaggingPrompt.userPayload(memory)]
            ],
            "response_format": ["type": "json_object"]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse("non-HTTP response")
        }
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.httpStatus(http.statusCode, body)
        }

        guard
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = obj["choices"] as? [[String: Any]],
            let msg = choices.first?["message"] as? [String: Any],
            let text = msg["content"] as? String
        else {
            throw LLMError.invalidResponse("missing content")
        }

        let parsed = try ClaudeProvider.parseJSON(text)
        return TaggingPrompt.sanitize(parsed)
    }

    func ping() async -> Bool {
        guard !apiKey.isEmpty else { return false }
        let dummy = Memory(type: .note, title: "ping", body: "test")
        return (try? await tagAndTitle(dummy)) != nil
    }

    /// Fetch the list of available model slugs (for Settings dropdown).
    static func listModels(apiKey: String) async throws -> [String] {
        var req = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse("no http") }
        if !(200..<300).contains(http.statusCode) {
            throw LLMError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["data"] as? [[String: Any]] else {
            throw LLMError.invalidResponse("malformed /models")
        }
        return arr.compactMap { $0["id"] as? String }.sorted()
    }
}
