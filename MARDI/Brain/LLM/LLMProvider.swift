import Foundation

/// Result of auto-tagging a freshly saved memory.
struct TagResult: Codable, Sendable, Equatable {
    var title: String       // ≤ 60 chars
    var tags: [String]      // 3-7 kebab-case
    var summary: String     // ≤ 140 chars
}

/// Optional model suggestions for normalizing a raw capture before it is
/// persisted. The app validates these fields before accepting them.
struct CaptureSuggestion: Codable, Sendable, Equatable {
    var type: String?
    var title: String?
    var tags: [String]?
    var summary: String?
    var body: String?
}

struct LLMChatMessage: Codable, Sendable, Equatable {
    var role: String
    var content: String
}

/// Abstract interface for any LLM provider. Implementations must honour the
/// same TagResult contract regardless of model quirks — do JSON validation
/// and fallback inside the provider, not in the caller.
protocol LLMProvider: Sendable {
    /// Human-readable name ("Claude", "OpenRouter · claude-sonnet-4.6")
    var displayName: String { get }

    /// Produce a title, tag set, and one-line summary for the given memory.
    func tagAndTitle(_ memory: Memory) async throws -> TagResult

    /// Suggest a normalized type and metadata for a raw capture. Callers must
    /// validate the result and keep deterministic fallbacks.
    func normalizeCapture(_ capture: RawCapture) async throws -> CaptureSuggestion

    /// Run a general chat turn for the dashboard agent.
    func completeChat(system: String, messages: [LLMChatMessage], maxTokens: Int) async throws -> String

    /// Quick liveness check. Should round-trip a trivial request and return
    /// true only if the provider is correctly configured and reachable.
    func ping() async -> Bool
}

enum LLMError: Error, LocalizedError {
    case missingAPIKey
    case networkFailure(String)
    case invalidResponse(String)
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "API key is missing. Set it in Settings → Model."
        case .networkFailure(let s): "Network failure: \(s)"
        case .invalidResponse(let s): "Invalid response: \(s)"
        case .httpStatus(let code, let body): "HTTP \(code): \(body)"
        }
    }
}

/// Shared system prompt that both providers use, so switching provider
/// doesn't change output shape.
enum TaggingPrompt {
    static let system = """
    You are a precise indexing assistant. Given a piece of content the user
    just saved to their personal knowledge base, produce a concise, factual
    title, a small set of kebab-case tags, and a one-line summary.

    Respond with JSON only, matching this exact schema:
    {
      "title": "string, ≤ 60 chars, no trailing punctuation",
      "tags":  ["kebab-case", "3 to 7 items", "topical not stylistic"],
      "summary": "string, ≤ 140 chars, single sentence"
    }

    Do not include any text outside the JSON. Do not wrap in markdown.
    """

    static func userPayload(_ m: Memory) -> String {
        var lines: [String] = []
        lines.append("Type: \(m.type.rawValue)")
        if let url = m.sourceURL { lines.append("Source URL: \(url)") }
        if let app = m.sourceApp { lines.append("Captured from app: \(app)") }
        lines.append("")
        lines.append("Content:")
        lines.append(m.body)
        return lines.joined(separator: "\n")
    }

    /// Normalise a parsed TagResult to meet the hard limits (in case the model
    /// produces something slightly over). Never throws; always returns usable data.
    static func sanitize(_ r: TagResult) -> TagResult {
        let title = String(r.title.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = String(r.summary.prefix(140)).trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = Array(
            r.tags
                .map { $0.lowercased().replacingOccurrences(of: "_", with: "-").replacingOccurrences(of: " ", with: "-") }
                .filter { !$0.isEmpty }
                .prefix(7)
        )
        return TagResult(title: title, tags: tags, summary: summary)
    }

    /// Deterministic fallback when the LLM call fails entirely.
    static func fallback(for memory: Memory) -> TagResult {
        let head = memory.body.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = memory.title.isEmpty
            ? "\(memory.type.displayName) · \(String(head.prefix(40)))"
            : memory.title
        return TagResult(title: title, tags: [memory.type.rawValue], summary: String(head.prefix(140)))
    }
}

/// Shared prompt for safe capture normalization. It lets the provider improve
/// metadata and suggest a better type while preserving the original content.
enum CaptureNormalizationPrompt {
    static let system = """
    You are Mardi, a careful second-brain companion. Normalize a user's raw
    capture into metadata that is safe to store in an Obsidian-like vault.

    Goals:
    - choose the best type only when there is clear evidence
    - produce a concise factual title
    - produce topical kebab-case tags
    - produce a one-line summary
    - preserve the user's content; do not invent details, commands, URLs, or facts

    Allowed types: url, snippet, ssh, prompt, signature, reply, note

    Respond with JSON only, matching this exact schema:
    {
      "type": "one of the allowed types",
      "title": "string, <= 60 chars, no trailing punctuation",
      "tags": ["kebab-case", "0 to 7 items"],
      "summary": "string, <= 140 chars, single sentence",
      "body": "string, usually the original content unchanged"
    }

    Keep `body` unchanged unless a tiny cleanup is obviously safe, such as
    trimming accidental surrounding whitespace.
    """

    static func userPayload(_ capture: RawCapture) -> String {
        var lines: [String] = []
        lines.append("Requested type: \(capture.requestedType.rawValue)")
        if let url = capture.sourceURL { lines.append("Source URL: \(url)") }
        if let app = capture.sourceApp { lines.append("Captured from app: \(app)") }
        if !capture.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("User title: \(capture.title)")
        }
        if !capture.tags.isEmpty {
            lines.append("User tags: \(capture.tags.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("Content:")
        lines.append(capture.body)
        return lines.joined(separator: "\n")
    }
}

enum LLMJSONParser {
    static func parse<T: Decodable>(_ text: String, as type: T.Type) throws -> T {
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
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if let start = s.firstIndex(of: "{"),
               let end = s.lastIndex(of: "}"),
               start < end {
                let slice = String(s[start...end])
                if let d2 = slice.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(T.self, from: d2) {
                    return decoded
                }
            }
            throw LLMError.invalidResponse("could not parse JSON payload: \(error.localizedDescription)")
        }
    }
}
