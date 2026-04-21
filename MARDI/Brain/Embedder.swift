import Foundation
import NaturalLanguage

/// Local sentence embeddings via Apple's NaturalLanguage framework.
/// No model download, fully on-device. Falls back gracefully if the platform
/// doesn't have a sentence embedding for the requested language.
final class Embedder: @unchecked Sendable {
    private let embedding: NLEmbedding?

    /// Number of dimensions for the active embedding model. Pinned to 512 if
    /// the native sentence embedding is available; otherwise we hash-embed to
    /// the same dimension so the DB schema doesn't have to change.
    let dimension: Int = 512

    init(language: NLLanguage = .english) {
        self.embedding = NLEmbedding.sentenceEmbedding(for: language)
    }

    /// Compute an embedding for the given text. Always returns a vector of
    /// length `dimension`. Returns a hashed fallback vector when the platform
    /// can't embed the text (e.g. non-English, extremely short strings).
    func embed(_ text: String) -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Array(repeating: 0, count: dimension) }

        if let emb = embedding {
            if let vec = emb.vector(for: trimmed) {
                return Embedder.resize(vec.map { Float($0) }, to: dimension)
            }
            // Try lowercased fallback
            if let vec = emb.vector(for: trimmed.lowercased()) {
                return Embedder.resize(vec.map { Float($0) }, to: dimension)
            }
        }

        // Deterministic hash fallback — not good quality but keeps retrieval non-broken.
        return Embedder.hashEmbedding(trimmed, dimension: dimension)
    }

    // Trim or zero-pad to `size` dimensions.
    private static func resize(_ vec: [Float], to size: Int) -> [Float] {
        if vec.count == size { return vec }
        if vec.count > size { return Array(vec.prefix(size)) }
        var out = vec
        out.append(contentsOf: Array(repeating: 0, count: size - vec.count))
        return out
    }

    private static func hashEmbedding(_ text: String, dimension: Int) -> [Float] {
        var out = [Float](repeating: 0, count: dimension)
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        for word in words {
            var h: UInt64 = 1469598103934665603  // FNV offset basis
            for b in word.utf8 {
                h ^= UInt64(b)
                h = h &* 1099511628211
            }
            let idx = Int(h % UInt64(dimension))
            let sign: Float = ((h >> 63) & 1) == 0 ? 1 : -1
            out[idx] += sign
        }
        let norm = sqrt(out.reduce(0) { $0 + $1 * $1 })
        if norm > 0 {
            for i in 0..<out.count { out[i] /= norm }
        }
        return out
    }
}
