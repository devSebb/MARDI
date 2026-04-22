import Foundation

enum AgentSidebarItem: Hashable {
    case thread(String)
    case file(String)
}

struct AgentSpecFile: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let relativePath: String
    var content: String
    var kind: Kind

    enum Kind: String, Codable, Sendable {
        case identity
        case style
        case rules
        case task
    }
}

struct AgentReference: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let type: String
    let summary: String?
    let folder: String?
    let markdownPath: String
}

struct AgentMessage: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let role: String
    var content: String
    let created: Date
    var references: [AgentReference]

    init(
        id: String = UUID().uuidString,
        role: String,
        content: String,
        created: Date = Date(),
        references: [AgentReference] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.created = created
        self.references = references
    }
}

struct AgentThread: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    let created: Date
    var updated: Date
    var messages: [AgentMessage]

    init(
        id: String = UUID().uuidString,
        title: String = "New Conversation",
        created: Date = Date(),
        updated: Date = Date(),
        messages: [AgentMessage] = []
    ) {
        self.id = id
        self.title = title
        self.created = created
        self.updated = updated
        self.messages = messages
    }
}
