import Foundation

/// Hits api.anthropic.com directly. Minimal — no streaming, no tool use, no caching.
/// One call per save. Fast models (Haiku 4.5) are the default.
final class ClaudeProvider: LLMProvider {
    let apiKey: String
    let model: String

    var displayName: String { "Claude · \(model)" }

    init(apiKey: String, model: String = "claude-haiku-4-5") {
        self.apiKey = apiKey
        self.model = model
    }

    func tagAndTitle(_ memory: Memory) async throws -> TagResult {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "system": TaggingPrompt.system,
            "messages": [
                ["role": "user", "content": TaggingPrompt.userPayload(memory)]
            ]
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

        // Anthropic messages API response: { content: [{ type: "text", text: "…" }] }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String else {
            throw LLMError.invalidResponse("missing content")
        }

        let parsed = try Self.parseJSON(firstText)
        return TaggingPrompt.sanitize(parsed)
    }

    func normalizeCapture(_ capture: RawCapture) async throws -> CaptureSuggestion {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 500,
            "system": CaptureNormalizationPrompt.system,
            "messages": [
                ["role": "user", "content": CaptureNormalizationPrompt.userPayload(capture)]
            ]
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

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String else {
            throw LLMError.invalidResponse("missing content")
        }

        return try LLMJSONParser.parse(firstText, as: CaptureSuggestion.self)
    }

    func completeChat(system: String, messages: [LLMChatMessage], maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 35
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
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

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]] else {
            throw LLMError.invalidResponse("missing content")
        }

        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LLMError.invalidResponse("empty content")
        }
        return text
    }

    func ping() async -> Bool {
        guard !apiKey.isEmpty else { return false }
        let dummy = Memory(type: .note, title: "ping", body: "test")
        return (try? await tagAndTitle(dummy)) != nil
    }

    static func parseJSON(_ text: String) throws -> TagResult {
        try LLMJSONParser.parse(text, as: TagResult.self)
    }
}
