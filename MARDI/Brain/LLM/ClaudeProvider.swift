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

    func ping() async -> Bool {
        guard !apiKey.isEmpty else { return false }
        let dummy = Memory(type: .note, title: "ping", body: "test")
        return (try? await tagAndTitle(dummy)) != nil
    }

    static func parseJSON(_ text: String) throws -> TagResult {
        // Strip any markdown fencing the model might still add.
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if let fenceEnd = s.range(of: "```", options: .backwards) {
                s = String(s[..<fenceEnd.lowerBound])
            }
        }
        guard let data = s.data(using: .utf8) else {
            throw LLMError.invalidResponse("non-utf8 JSON")
        }
        do {
            return try JSONDecoder().decode(TagResult.self, from: data)
        } catch {
            // Try to salvage by finding the first {…} block
            if let start = s.firstIndex(of: "{"),
               let end = s.lastIndex(of: "}"),
               start < end {
                let slice = String(s[start...end])
                if let d2 = slice.data(using: .utf8),
                   let r = try? JSONDecoder().decode(TagResult.self, from: d2) {
                    return r
                }
            }
            throw LLMError.invalidResponse("could not parse TagResult: \(error.localizedDescription)")
        }
    }
}
