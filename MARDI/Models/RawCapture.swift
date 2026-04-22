import Foundation

/// Raw user input collected by the monster before any LLM or deterministic
/// normalization decides the final persisted memory shape.
struct RawCapture: Codable, Hashable, Sendable {
    let id: String
    var requestedType: MemoryType
    var title: String
    var body: String
    var tags: [String]
    var folder: String?
    var sourceApp: String?
    var sourceURL: String?
    var created: Date

    init(
        id: String = Memory.newID(),
        requestedType: MemoryType,
        title: String,
        body: String,
        tags: [String] = [],
        folder: String? = nil,
        sourceApp: String? = nil,
        sourceURL: String? = nil,
        created: Date = Date()
    ) {
        self.id = id
        self.requestedType = requestedType
        self.title = title
        self.body = body
        self.tags = tags
        self.folder = folder
        self.sourceApp = sourceApp
        self.sourceURL = sourceURL
        self.created = created
    }
}
