import Foundation

/// Lightweight projection of a memory used by the graph view. Only the fields
/// needed to render nodes and compute edges are loaded — body/summary/etc.
/// are intentionally omitted to keep the all-pairs cosine pass cheap.
struct GraphNodeRow: Identifiable, Sendable {
    let id: String
    let title: String
    let type: MemoryType
    let tags: [String]
    let embedding: [Float]
}
