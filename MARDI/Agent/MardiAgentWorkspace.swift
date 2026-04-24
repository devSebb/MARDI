import Foundation

@MainActor
final class MardiAgentWorkspace: ObservableObject {
    @Published var files: [AgentSpecFile] = []
    @Published var threads: [AgentThread] = []
    @Published var selectedItem: AgentSidebarItem?
    @Published var sending = false
    @Published var lastError: String?

    private let vault: Vault
    private let settings: AppSettings
    private let search: SearchService

    init(vault: Vault, settings: AppSettings, search: SearchService) {
        self.vault = vault
        self.settings = settings
        self.search = search
    }

    func load() async {
        do {
            try ensureStructure()
            try ensureDefaultFiles()
            files = try loadFiles()
            threads = try loadThreads()
            if selectedItem == nil {
                selectedItem = threads.first.map { .thread($0.id) } ?? files.first.map { .file($0.id) }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createThread() {
        var thread = AgentThread()
        thread.messages = [AgentMessage(role: "assistant", content: "What do you want to work through from your vault?")]
        thread.title = "New Conversation"
        thread.updated = Date()
        threads.insert(thread, at: 0)
        selectedItem = .thread(thread.id)
        persistThread(thread)
    }

    func save(fileID: String, content: String) {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }
        files[index].content = content
        let url = agentRootURL.appendingPathComponent(files[index].relativePath)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func send(message: String, threadID: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard settings.hasAPIKey else {
            lastError = "Set an API key in Settings before chatting with Mardi."
            return
        }
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }

        sending = true
        lastError = nil
        var thread = threads[index]
        let userMessage = AgentMessage(role: "user", content: trimmed)
        thread.messages.append(userMessage)
        thread.updated = Date()
        retitleIfNeeded(&thread)
        threads[index] = thread
        persistThread(thread)

        do {
            let memories = try await search.search(query: trimmed, k: 6)
            let references = memories.map(Self.reference(from:))
            let response = try await provider().completeChat(
                system: systemPrompt(references: references),
                messages: chatMessages(for: thread, query: trimmed, references: references),
                maxTokens: 700
            )
            var updated = thread
            updated.messages.append(AgentMessage(role: "assistant", content: response, references: references))
            updated.updated = Date()
            if updated.title == "New Conversation" {
                updated.title = suggestedTitle(from: trimmed)
            }
            threads[index] = updated
            persistThread(updated)
        } catch {
            lastError = (error as NSError).localizedDescription
            var failed = thread
            failed.messages.append(AgentMessage(role: "assistant", content: "I hit a provider error while answering. Check the API settings and try again."))
            failed.updated = Date()
            threads[index] = failed
            persistThread(failed)
        }

        sending = false
    }

    func thread(for id: String) -> AgentThread? {
        threads.first(where: { $0.id == id })
    }

    private func provider() -> LLMProvider {
        settings.buildProvider()
    }

    private func systemPrompt(references: [AgentReference]) -> String {
        let identity = content(for: "identity")
        let style = content(for: "style")
        let rules = content(for: "rules")
        let tasks = files.filter { $0.kind == .task }.map(\.content).joined(separator: "\n\n---\n\n")
        let referenceHeader: String
        if references.isEmpty {
            referenceHeader = "No relevant memories were retrieved for this turn."
        } else {
            referenceHeader = """
            Retrieved memories for this turn:
            \(references.map { "- [\($0.type)] \($0.title) | folder: \($0.folder ?? "none") | path: \($0.markdownPath)" }.joined(separator: "\n"))
            """
        }

        return [
            identity,
            style,
            rules,
            tasks,
            "Runtime rules:",
            "- You are operating inside MARDI's dashboard-only agent surface.",
            "- Use the retrieved memories as your factual grounding.",
            "- State when you are inferring rather than directly citing memories.",
            "- Do not claim to have changed memories or folders unless the app explicitly supports that action in the UI.",
            "- Keep answers useful, concrete, and specific to the vault.",
            referenceHeader
        ].joined(separator: "\n\n")
    }

    private func chatMessages(for thread: AgentThread, query: String, references: [AgentReference]) -> [LLMChatMessage] {
        let history = thread.messages.suffix(8).map { LLMChatMessage(role: $0.role, content: $0.content) }
        let memoryContext = references.isEmpty ? "" : """

        Relevant memory excerpts:
        \(references.map { ref in
            let summary = ref.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No summary available."
            return "- \(ref.title) [\(ref.type)] folder=\(ref.folder ?? "none") path=\(ref.markdownPath)\n  \(summary)"
        }.joined(separator: "\n"))
        """
        let current = LLMChatMessage(role: "user", content: query + memoryContext)
        return Array(history.dropLast()) + [current]
    }

    private func content(for name: String) -> String {
        files.first(where: { $0.id == name })?.content ?? ""
    }

    private func retitleIfNeeded(_ thread: inout AgentThread) {
        guard thread.title == "New Conversation" else { return }
        if let firstUser = thread.messages.first(where: { $0.role == "user" }) {
            thread.title = suggestedTitle(from: firstUser.content)
        }
    }

    private func suggestedTitle(from text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(42)).isEmpty ? "New Conversation" : String(cleaned.prefix(42))
    }

    private func persistThread(_ thread: AgentThread) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(thread)
            try data.write(to: threadURL(id: thread.id), options: .atomic)
            threads.sort { $0.updated > $1.updated }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func loadFiles() throws -> [AgentSpecFile] {
        let ordered: [(String, String, AgentSpecFile.Kind)] = [
            ("identity", "identity.md", .identity),
            ("style", "style.md", .style),
            ("rules", "rules.md", .rules),
            ("recall", "tasks/recall.md", .task),
            ("organize", "tasks/organize.md", .task),
            ("collections", "tasks/collections.md", .task),
            ("write-from-memories", "tasks/write-from-memories.md", .task)
        ]

        return try ordered.map { id, path, kind in
            let url = agentRootURL.appendingPathComponent(path)
            let content = try String(contentsOf: url, encoding: .utf8)
            return AgentSpecFile(
                id: id,
                title: title(for: id),
                relativePath: path,
                content: content,
                kind: kind
            )
        }
    }

    private func loadThreads() throws -> [AgentThread] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: threadsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try urls
            .filter { $0.pathExtension == "json" }
            .map { try decoder.decode(AgentThread.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updated > $1.updated }
    }

    private func ensureStructure() throws {
        try FileManager.default.createDirectory(at: agentRootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tasksURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: threadsURL, withIntermediateDirectories: true)
    }

    private func ensureDefaultFiles() throws {
        for (path, content) in Self.defaultFiles {
            let url = agentRootURL.appendingPathComponent(path)
            if !FileManager.default.fileExists(atPath: url.path) {
                try content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func threadURL(id: String) -> URL {
        threadsURL.appendingPathComponent("\(id).json")
    }

    private var agentRootURL: URL {
        vault.rootURL.appendingPathComponent(".mardi/agent", isDirectory: true)
    }

    private var tasksURL: URL {
        agentRootURL.appendingPathComponent("tasks", isDirectory: true)
    }

    private var threadsURL: URL {
        agentRootURL.appendingPathComponent("threads", isDirectory: true)
    }

    private static func reference(from memory: Memory) -> AgentReference {
        AgentReference(
            id: memory.id,
            title: memory.title,
            type: memory.type.displayName,
            summary: memory.summary,
            folder: memory.folder,
            markdownPath: memory.markdownPath
        )
    }

    private func title(for id: String) -> String {
        switch id {
        case "identity": "Identity"
        case "style": "Style"
        case "rules": "Rules"
        case "recall": "Recall Task"
        case "organize": "Organize Task"
        case "collections": "Collections Task"
        case "write-from-memories": "Write Task"
        default: id
        }
    }
}

private extension MardiAgentWorkspace {
    static let defaultFiles: [(String, String)] = [
        ("identity.md", """
        # Mardi Identity

        Mardi is a calm, exacting second-brain companion inside the MARDI dashboard.
        Mardi helps the user understand what has been captured, what patterns exist across memories, and what to do next.
        Mardi is not a generic chatbot. Mardi is grounded in the user's vault and should stay close to the actual saved material.
        """),
        ("style.md", """
        # Mardi Style

        - Be concise, specific, and useful.
        - Prefer direct answers over motivational language.
        - Separate facts from inference.
        - When useful, propose concrete next actions or better organization.
        - Match the user's level of formality without becoming stiff.
        """),
        ("rules.md", """
        # Mardi Rules

        - Use retrieved memories as the primary factual source.
        - If something is not in the vault, say so.
        - Do not invent quotes, links, or memory contents.
        - Distinguish between what a memory says and what you infer from multiple memories.
        - Do not claim to have moved, renamed, merged, or edited memories unless the UI explicitly performed that action.
        """),
        ("tasks/recall.md", """
        # Recall Task

        Help the user recall what exists in the vault.
        Good outputs include:
        - summaries of what is known about a topic
        - grouped findings across related memories
        - important open questions or gaps in the saved material
        """),
        ("tasks/organize.md", """
        # Organize Task

        Help the user organize saved material.
        Good outputs include:
        - suggested folders
        - suggested tags
        - duplicate detection
        - recommendations for which memories belong together
        """),
        ("tasks/collections.md", """
        # Collections Task

        Treat folders, especially URL folders, as lightweight collections.
        Good outputs include:
        - collection summaries
        - thematic grouping
        - identifying the strongest or weakest links in a collection
        """),
        ("tasks/write-from-memories.md", """
        # Write From Memories Task

        Use the vault to help draft useful output.
        Good outputs include:
        - briefings
        - follow-up drafts
        - structured notes
        - summaries based on saved replies, signatures, prompts, snippets, and URLs
        """)
    ]
}
