import Foundation
import Yams

/// Read/write memories as plain markdown with YAML frontmatter. Obsidian-compatible.
///
/// On-disk layout:
///     <vaultRoot>/_urls/2026-04-20-143211-<slug>.md
///     <vaultRoot>/_snippets/...
///     <vaultRoot>/.mardi/mardi.sqlite
///     <vaultRoot>/.mardi/thumbnails/<id>.png
///     <vaultRoot>/.mardi/pending/<id>.json
final class Vault {
    let rootURL: URL

    static let defaultPath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("MARDI-Vault", isDirectory: true)
    }()

    init(rootURL: URL = Vault.defaultPath) throws {
        self.rootURL = rootURL
        try Self.ensureStructure(at: rootURL)
    }

    static func ensureStructure(at url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        for type in MemoryType.allCases {
            let typeDir = url.appendingPathComponent(type.folderName, isDirectory: true)
            try fm.createDirectory(at: typeDir, withIntermediateDirectories: true)
        }
        let hidden = url.appendingPathComponent(".mardi", isDirectory: true)
        try fm.createDirectory(at: hidden, withIntermediateDirectories: true)
        let thumbs = hidden.appendingPathComponent("thumbnails", isDirectory: true)
        try fm.createDirectory(at: thumbs, withIntermediateDirectories: true)
        let pending = hidden.appendingPathComponent("pending", isDirectory: true)
        try fm.createDirectory(at: pending, withIntermediateDirectories: true)
        let agent = hidden.appendingPathComponent("agent", isDirectory: true)
        try fm.createDirectory(at: agent, withIntermediateDirectories: true)
        let agentTasks = agent.appendingPathComponent("tasks", isDirectory: true)
        try fm.createDirectory(at: agentTasks, withIntermediateDirectories: true)
        let agentThreads = agent.appendingPathComponent("threads", isDirectory: true)
        try fm.createDirectory(at: agentThreads, withIntermediateDirectories: true)
    }

    var sqliteURL: URL {
        rootURL.appendingPathComponent(".mardi/mardi.sqlite")
    }

    var thumbnailsURL: URL {
        rootURL.appendingPathComponent(".mardi/thumbnails")
    }

    var pendingURL: URL {
        rootURL.appendingPathComponent(".mardi/pending")
    }

    // MARK: - Write

    @discardableResult
    func write(_ memory: Memory) throws -> Memory {
        var m = memory
        let relPath: String
        if !memory.markdownPath.isEmpty {
            relPath = memory.markdownPath
        } else {
            let filename = Self.filename(for: memory)
            relPath = "\(memory.type.folderName)/\(filename)"
        }
        let fileURL = rootURL.appendingPathComponent(relPath)

        let frontmatter = FrontMatter(
            id: m.id,
            type: m.type.rawValue,
            title: m.title,
            tags: m.tags,
            folder: m.folder,
            created: Self.iso8601.string(from: m.created),
            source_app: m.sourceApp,
            source_url: m.sourceURL,
            thumbnail: m.thumbnailPath,
            summary: m.summary
        )

        let yaml = try YAMLEncoder().encode(frontmatter)
        let markdown = "---\n\(yaml)---\n\n\(m.body)\n"

        try markdown.data(using: .utf8)?.write(to: fileURL, options: .atomic)
        m.markdownPath = relPath
        return m
    }

    func delete(_ memory: Memory) throws {
        let url = rootURL.appendingPathComponent(memory.markdownPath)
        try? FileManager.default.removeItem(at: url)
        if let thumb = memory.thumbnailPath {
            let thumbURL = rootURL.appendingPathComponent(thumb)
            try? FileManager.default.removeItem(at: thumbURL)
        }
    }

    // MARK: - Pending journal

    func stagePending(_ memory: Memory) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(memory)
        try data.write(to: pendingItemURL(id: memory.id), options: .atomic)
    }

    func removePending(id: String) throws {
        try? FileManager.default.removeItem(at: pendingItemURL(id: id))
    }

    func pendingMemories() throws -> [Memory] {
        let fm = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let urls = try fm.contentsOfDirectory(
            at: pendingURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let sorted = try urls.sorted { lhs, rhs in
            let ld = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rd = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return ld < rd
        }

        var out: [Memory] = []
        for url in sorted where url.pathExtension.lowercased() == "json" {
            let data = try Data(contentsOf: url)
            if let memory = try? decoder.decode(Memory.self, from: data) {
                out.append(memory)
            }
        }
        return out
    }

    func allMemories() throws -> [Memory] {
        let fm = FileManager.default
        var memories: [Memory] = []

        for type in MemoryType.allCases where type != .select {
            let dirURL = rootURL.appendingPathComponent(type.folderName, isDirectory: true)
            let urls = try fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let sorted = try urls.sorted { lhs, rhs in
                let ld = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
                let rd = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
                return ld > rd
            }

            for url in sorted where url.pathExtension.lowercased() == "md" {
                let relativePath = relativePath(for: url)
                if let memory = try read(relativePath: relativePath) {
                    memories.append(memory)
                }
            }
        }

        return memories
    }

    // MARK: - Read

    func read(relativePath: String) throws -> Memory? {
        let url = rootURL.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return try parse(text, markdownPath: relativePath)
    }

    func parse(_ text: String, markdownPath: String) throws -> Memory? {
        // Extract frontmatter block between leading --- ... ---\n\n
        guard text.hasPrefix("---") else { return nil }
        let afterFirst = text.dropFirst(3)
        guard let closeRange = afterFirst.range(of: "\n---") else { return nil }
        let yamlText = String(afterFirst[afterFirst.startIndex..<closeRange.lowerBound])
        let bodyStart = afterFirst.index(closeRange.upperBound, offsetBy: 0)
        var body = String(afterFirst[bodyStart...])
        if body.hasPrefix("\n") { body.removeFirst() }
        if body.hasPrefix("\n") { body.removeFirst() }

        let fm: FrontMatter = try YAMLDecoder().decode(FrontMatter.self, from: yamlText)
        let type = MemoryType(rawValue: fm.type) ?? .note
        let created = Self.iso8601.date(from: fm.created) ?? Date()
        return Memory(
            id: fm.id,
            type: type,
            title: fm.title,
            summary: fm.summary,
            body: body,
            tags: fm.tags ?? [],
            folder: fm.folder,
            sourceApp: fm.source_app,
            sourceURL: fm.source_url,
            thumbnailPath: fm.thumbnail,
            created: created,
            markdownPath: markdownPath
        )
    }

    // MARK: - Helpers

    static func filename(for memory: Memory) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmmss"
        df.timeZone = .current
        let ts = df.string(from: memory.created)
        let slug = slugify(memory.title)
        let trimmed = slug.isEmpty ? memory.id : slug
        return "\(ts)-\(trimmed).md"
    }

    static func slugify(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: " -"))
        let lowered = input.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        let scalars = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let collapsed = String(scalars)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return String(collapsed.prefix(48))
    }

    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func pendingItemURL(id: String) -> URL {
        pendingURL.appendingPathComponent("\(id).json")
    }

    private func relativePath(for url: URL) -> String {
        let root = rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root) else { return url.lastPathComponent }
        return String(path.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

// MARK: - Frontmatter shape

private struct FrontMatter: Codable {
    var id: String
    var type: String
    var title: String
    var tags: [String]?
    var folder: String?
    var created: String
    var source_app: String?
    var source_url: String?
    var thumbnail: String?
    var summary: String?
}
