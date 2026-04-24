import Foundation

struct Memory: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var type: MemoryType
    var title: String
    var summary: String?
    var body: String
    var tags: [String]
    var folder: String?
    var sourceApp: String?
    var sourceURL: String?
    var thumbnailPath: String?
    var created: Date
    var markdownPath: String

    init(
        id: String = Memory.newID(),
        type: MemoryType,
        title: String,
        summary: String? = nil,
        body: String,
        tags: [String] = [],
        folder: String? = nil,
        sourceApp: String? = nil,
        sourceURL: String? = nil,
        thumbnailPath: String? = nil,
        created: Date = Date(),
        markdownPath: String = ""
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.summary = summary
        self.body = body
        self.tags = tags
        self.folder = folder
        self.sourceApp = sourceApp
        self.sourceURL = sourceURL
        self.thumbnailPath = thumbnailPath
        self.created = created
        self.markdownPath = markdownPath
    }

    static func newID() -> String {
        let alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        var s = ""
        for _ in 0..<26 {
            s.append(alphabet.randomElement()!)
        }
        return s
    }
}
