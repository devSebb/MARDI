import Foundation
import SQLiteVec

/// Co-located metadata + FTS5 + embedding BLOBs in one SQLite file.
///
/// We use SQLiteVec's plain SQLite bindings for storage, FTS5 for keyword
/// search, and do cosine similarity in Swift over the embedding BLOBs.
/// This sidesteps sqlite-vec's vec0 table schema quirks (TEXT primary key
/// isn't supported there) and is plenty fast for v0-scale vaults.
actor MemoryStore {
    private let db: Database

    init(path: URL) async throws {
        try SQLiteVec.initialize()
        self.db = try Database(.uri(path.path))
    }

    /// Run schema migrations. Split from init so boot failures surface
    /// cleanly without leaving a half-initialised actor.
    func setup() async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS memories (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                summary TEXT,
                body TEXT NOT NULL,
                tags TEXT,
                source_app TEXT,
                source_url TEXT,
                thumbnail_path TEXT,
                created INTEGER NOT NULL,
                markdown_path TEXT NOT NULL,
                embedding BLOB
            );
            """
        )
        try await db.execute("CREATE INDEX IF NOT EXISTS idx_memories_type ON memories(type);")
        try await db.execute("CREATE INDEX IF NOT EXISTS idx_memories_created ON memories(created DESC);")

        try await db.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
                id UNINDEXED,
                title,
                summary,
                body,
                tags,
                tokenize='porter unicode61'
            );
            """
        )
    }

    // MARK: - Write

    func upsert(_ m: Memory, embedding: [Float]) async throws {
        let tagsJSON = (try? String(data: JSONEncoder().encode(m.tags), encoding: .utf8)) ?? "[]"
        let createdMs = Int64(m.created.timeIntervalSince1970 * 1000)
        let blob = Self.encode(embedding)

        try await db.execute(
            """
            INSERT OR REPLACE INTO memories
            (id, type, title, summary, body, tags, source_app, source_url,
             thumbnail_path, created, markdown_path, embedding)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            params: [
                m.id,
                m.type.rawValue,
                m.title,
                m.summary ?? "",
                m.body,
                tagsJSON,
                m.sourceApp ?? "",
                m.sourceURL ?? "",
                m.thumbnailPath ?? "",
                createdMs,
                m.markdownPath,
                blob
            ]
        )

        try await db.execute("DELETE FROM memories_fts WHERE id = ?;", params: [m.id])
        try await db.execute(
            "INSERT INTO memories_fts (id, title, summary, body, tags) VALUES (?, ?, ?, ?, ?);",
            params: [m.id, m.title, m.summary ?? "", m.body, m.tags.joined(separator: " ")]
        )
    }

    func delete(id: String) async throws {
        try await db.execute("DELETE FROM memories WHERE id = ?;", params: [id])
        try await db.execute("DELETE FROM memories_fts WHERE id = ?;", params: [id])
    }

    // MARK: - Read

    func all(type: MemoryType? = nil, limit: Int = 500) async throws -> [Memory] {
        let rows: [[String: any Sendable]]
        if let t = type {
            rows = try await db.query(
                "SELECT * FROM memories WHERE type = ? ORDER BY created DESC LIMIT ?;",
                params: [t.rawValue, limit]
            )
        } else {
            rows = try await db.query(
                "SELECT * FROM memories ORDER BY created DESC LIMIT ?;",
                params: [limit]
            )
        }
        return rows.compactMap(Self.memoryFromRow)
    }

    func get(id: String) async throws -> Memory? {
        let rows = try await db.query("SELECT * FROM memories WHERE id = ?;", params: [id])
        return rows.first.flatMap(Self.memoryFromRow)
    }

    func countsByType() async throws -> [MemoryType: Int] {
        let rows = try await db.query("SELECT type, COUNT(*) as c FROM memories GROUP BY type;")
        var out: [MemoryType: Int] = [:]
        for row in rows {
            if let typeStr = row["type"] as? String,
               let mt = MemoryType(rawValue: typeStr) {
                let count = (row["c"] as? Int64).map(Int.init) ?? (row["c"] as? Int) ?? 0
                out[mt] = count
            }
        }
        return out
    }

    // MARK: - Hybrid search

    func search(embedding: [Float], keywordQuery: String, typeFilter: MemoryType? = nil, k: Int = 20) async throws -> [Memory] {
        async let vectorHits = vectorSearch(embedding: embedding, typeFilter: typeFilter, k: k)
        async let ftsHits = ftsSearch(query: keywordQuery, typeFilter: typeFilter, k: k)

        let vec = try await vectorHits
        let fts = try await ftsHits

        // Reciprocal Rank Fusion.
        let c: Double = 60
        var score: [String: Double] = [:]
        for (rank, id) in vec.enumerated() {
            score[id, default: 0] += 1.0 / (c + Double(rank) + 1)
        }
        for (rank, id) in fts.enumerated() {
            score[id, default: 0] += 1.0 / (c + Double(rank) + 1)
        }

        let merged = score
            .sorted { $0.value > $1.value }
            .prefix(k)
            .map { $0.key }

        var results: [Memory] = []
        for id in merged {
            if let m = try await get(id: id) { results.append(m) }
        }
        return results
    }

    private func vectorSearch(embedding query: [Float], typeFilter: MemoryType?, k: Int) async throws -> [String] {
        let sql: String
        let params: [any Sendable]
        if let tf = typeFilter {
            sql = "SELECT id, embedding FROM memories WHERE type = ? AND embedding IS NOT NULL;"
            params = [tf.rawValue]
        } else {
            sql = "SELECT id, embedding FROM memories WHERE embedding IS NOT NULL;"
            params = []
        }
        let rows = try await db.query(sql, params: params)
        var scored: [(String, Float)] = []
        scored.reserveCapacity(rows.count)
        for row in rows {
            guard
                let id = row["id"] as? String,
                let blob = row["embedding"] as? Data
            else { continue }
            let vec = Self.decode(blob)
            if vec.count != query.count { continue }
            let sim = Self.cosine(vec, query)
            scored.append((id, sim))
        }
        scored.sort { $0.1 > $1.1 }
        return scored.prefix(k).map { $0.0 }
    }

    private func ftsSearch(query: String, typeFilter: MemoryType?, k: Int) async throws -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let q = Self.sanitizeFTS(trimmed)
        let rows: [[String: any Sendable]]
        if let tf = typeFilter {
            rows = try await db.query(
                """
                SELECT f.id AS id FROM memories_fts f
                JOIN memories m ON m.id = f.id
                WHERE memories_fts MATCH ? AND m.type = ?
                ORDER BY rank LIMIT ?;
                """,
                params: [q, tf.rawValue, k]
            )
        } else {
            rows = try await db.query(
                """
                SELECT id FROM memories_fts
                WHERE memories_fts MATCH ?
                ORDER BY rank LIMIT ?;
                """,
                params: [q, k]
            )
        }
        return rows.compactMap { $0["id"] as? String }
    }

    // MARK: - Helpers

    private static func sanitizeFTS(_ input: String) -> String {
        let tokens = input
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        if tokens.isEmpty { return "\"\"" }
        return tokens.map { "\($0)*" }.joined(separator: " ")
    }

    private static func encode(_ vec: [Float]) -> Data {
        vec.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private static func decode(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { raw -> [Float] in
            let buf = raw.bindMemory(to: Float.self)
            return Array(UnsafeBufferPointer(start: buf.baseAddress, count: count))
        }
    }

    private static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        var dot: Float = 0
        var na: Float = 0
        var nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = sqrt(na) * sqrt(nb)
        if denom == 0 { return 0 }
        return dot / denom
    }

    private static func memoryFromRow(_ row: [String: any Sendable]) -> Memory? {
        guard
            let id = row["id"] as? String,
            let typeStr = row["type"] as? String,
            let title = row["title"] as? String,
            let body = row["body"] as? String,
            let type = MemoryType(rawValue: typeStr),
            let markdownPath = row["markdown_path"] as? String
        else { return nil }

        let createdMs: Int64 = (row["created"] as? Int64) ?? Int64((row["created"] as? Int) ?? 0)
        let created = Date(timeIntervalSince1970: TimeInterval(createdMs) / 1000.0)
        let summary = (row["summary"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let tagsJSON = row["tags"] as? String ?? "[]"
        let tags = (try? JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))) ?? []

        let sourceApp = (row["source_app"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let sourceURL = (row["source_url"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let thumbnail = (row["thumbnail_path"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        return Memory(
            id: id,
            type: type,
            title: title,
            summary: summary,
            body: body,
            tags: tags,
            sourceApp: sourceApp,
            sourceURL: sourceURL,
            thumbnailPath: thumbnail,
            created: created,
            markdownPath: markdownPath
        )
    }
}
