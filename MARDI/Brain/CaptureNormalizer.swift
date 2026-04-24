import Foundation

/// Normalizes raw UI capture into a validated `Memory`. The LLM may suggest a
/// better title, tags, summary, and type, but deterministic rules remain the
/// final authority so persistence stays reliable.
final class CaptureNormalizer: Sendable {
    private let provider: LLMProvider?

    init(provider: LLMProvider?) {
        self.provider = provider
    }

    func normalize(_ raw: RawCapture, allowLLM: Bool = true) async -> Memory {
        let baseline = Self.baselineMemory(from: raw)
        guard allowLLM, let provider else { return baseline }

        do {
            let suggestion = try await provider.normalizeCapture(raw)
            return Self.merge(raw: raw, baseline: baseline, suggestion: suggestion)
        } catch {
            return baseline
        }
    }

    private static func merge(raw: RawCapture, baseline: Memory, suggestion: CaptureSuggestion) -> Memory {
        let type = acceptedType(
            suggestion.type?.trimmingCharacters(in: .whitespacesAndNewlines),
            raw: raw,
            baseline: baseline
        )

        let title = acceptedTitle(suggestion.title) ?? baseline.title
        let summary = acceptedSummary(suggestion.summary) ?? baseline.summary
        let tags = mergedTags(userTags: raw.tags, suggestedTags: suggestion.tags, fallbackType: type)
        let sourceURL = type == .url ? (baseline.sourceURL ?? firstURL(in: baseline.body)) : baseline.sourceURL

        return Memory(
            id: baseline.id,
            type: type,
            title: title,
            summary: summary,
            body: baseline.body,
            tags: tags,
            folder: baseline.folder,
            sourceApp: baseline.sourceApp,
            sourceURL: sourceURL,
            thumbnailPath: baseline.thumbnailPath,
            created: baseline.created,
            markdownPath: baseline.markdownPath
        )
    }

    private static func baselineMemory(from raw: RawCapture) -> Memory {
        let body = normalizedBody(raw)
        let inferredType = inferType(from: raw, body: body)
        let title = raw.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let userTags = mergedTags(userTags: raw.tags, suggestedTags: [], fallbackType: inferredType)
        let sourceURL = resolvedSourceURL(for: inferredType, raw: raw, body: body)

        var memory = Memory(
            id: raw.id,
            type: inferredType,
            title: title,
            body: body,
            tags: userTags,
            folder: normalizedFolder(raw.folder),
            sourceApp: raw.sourceApp,
            sourceURL: sourceURL,
            created: raw.created
        )

        let fallback = TaggingPrompt.fallback(for: memory)
        if memory.title.isEmpty {
            memory.title = fallback.title
        }
        if memory.tags.isEmpty {
            memory.tags = fallback.tags
        }
        memory.summary = fallback.summary
        return memory
    }

    private static func normalizedBody(_ raw: RawCapture) -> String {
        let trimmed = raw.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if let url = raw.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return url
        }
        return raw.body
    }

    private static func normalizedFolder(_ folder: String?) -> String? {
        let trimmed = folder?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(40))
    }

    private static func inferType(from raw: RawCapture, body: String) -> MemoryType {
        if raw.requestedType == .url {
            return .url
        }
        if raw.requestedType == .note || raw.requestedType == .snippet || raw.requestedType == .prompt {
            if firstURL(in: body) != nil {
                return .url
            }
            if looksLikeSSH(body) {
                return .ssh
            }
        }
        return raw.requestedType
    }

    private static func acceptedType(_ suggested: String?, raw: RawCapture, baseline: Memory) -> MemoryType {
        guard let suggested,
              let parsed = MemoryType(rawValue: suggested.lowercased()) else {
            return baseline.type
        }
        if parsed == baseline.type {
            return parsed
        }

        // Only accept cross-type changes when deterministic evidence supports
        // the suggestion. This prevents a model from reclassifying content
        // incorrectly and keeps the storage taxonomy stable.
        switch parsed {
        case .url:
            return firstURL(in: baseline.body) != nil ? .url : baseline.type
        case .ssh:
            return looksLikeSSH(baseline.body) ? .ssh : baseline.type
        case .note:
            return raw.requestedType == .note ? .note : baseline.type
        default:
            return raw.requestedType == .note ? parsed : baseline.type
        }
    }

    private static func acceptedTitle(_ suggested: String?) -> String? {
        let trimmed = suggested?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(60))
    }

    private static func acceptedSummary(_ suggested: String?) -> String? {
        let trimmed = suggested?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(140))
    }

    private static func mergedTags(userTags: [String], suggestedTags: [String]?, fallbackType: MemoryType) -> [String] {
        let combined = userTags + (suggestedTags ?? []) + [fallbackType.rawValue]
        var seen: Set<String> = []
        var out: [String] = []

        for tag in combined {
            let normalized = tag
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "-")
                .replacingOccurrences(of: " ", with: "-")
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            out.append(String(normalized.prefix(24)))
            if out.count == 7 { break }
        }
        return out
    }

    private static func resolvedSourceURL(for type: MemoryType, raw: RawCapture, body: String) -> String? {
        if let explicit = raw.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !explicit.isEmpty {
            return explicit
        }
        guard type == .url else { return nil }
        return firstURL(in: body)
    }

    private static func firstURL(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector?.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }

    private static func looksLikeSSH(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        return lower.hasPrefix("ssh ")
            || lower.hasPrefix("scp ")
            || lower.hasPrefix("sftp ")
            || lower.contains(" user@")
            || lower.contains(" root@")
            || lower.contains("ssh://")
    }
}
