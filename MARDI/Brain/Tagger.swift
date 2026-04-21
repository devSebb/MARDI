import Foundation

/// Wraps any `LLMProvider` to enrich a raw memory with title/tags/summary.
/// Never throws to the UI — on failure, falls back to a deterministic result
/// so save never blocks.
final class Tagger: Sendable {
    private let provider: LLMProvider

    init(provider: LLMProvider) {
        self.provider = provider
    }

    func enrich(_ memory: Memory) async -> Memory {
        var enriched = memory
        do {
            let result = try await provider.tagAndTitle(memory)
            if enriched.title.isEmpty { enriched.title = result.title }
            if enriched.tags.isEmpty { enriched.tags = result.tags }
            enriched.summary = result.summary
        } catch {
            let fb = TaggingPrompt.fallback(for: memory)
            if enriched.title.isEmpty { enriched.title = fb.title }
            if enriched.tags.isEmpty { enriched.tags = fb.tags }
            enriched.summary = fb.summary
        }
        return enriched
    }
}
