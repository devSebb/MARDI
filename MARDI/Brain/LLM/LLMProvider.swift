import Foundation

/// Result of auto-tagging a freshly saved memory.
struct TagResult: Codable, Sendable, Equatable {
    var title: String       // ≤ 60 chars
    var tags: [String]      // 3-7 kebab-case
    var summary: String     // ≤ 140 chars
}

/// Abstract interface for any LLM provider. Implementations must honour the
/// same TagResult contract regardless of model quirks — do JSON validation
/// and fallback inside the provider, not in the caller.
protocol LLMProvider: Sendable {
    /// Human-readable name ("Claude", "OpenRouter · claude-sonnet-4.6")
    var displayName: String { get }

    /// Produce a title, tag set, and one-line summary for the given memory.
    func tagAndTitle(_ memory: Memory) async throws -> TagResult

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
