import Foundation

/// Thin wrapper over `MemoryStore` + `Embedder` that gives the UI a single call
/// to run hybrid retrieval. Keeps the store interface focused on storage;
/// keeps the embedder interface focused on vector generation.
final class SearchService: Sendable {
    private let store: MemoryStore
    private let embedder: Embedder

    init(store: MemoryStore, embedder: Embedder) {
        self.store = store
        self.embedder = embedder
    }

    func search(query: String, type: MemoryType? = nil, k: Int = 20) async throws -> [Memory] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return try await store.all(type: type, limit: k)
        }
        let vec = embedder.embed(trimmed)
        return try await store.search(embedding: vec, keywordQuery: trimmed, typeFilter: type, k: k)
    }
}
