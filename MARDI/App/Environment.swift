import Foundation
import SwiftUI
import Combine

/// Central DI container. Built once at launch, injected via `@EnvironmentObject`.
/// Owns the vault, store, embedder, LLM provider, active-app watcher, and the
/// monster's current view model. If boot fails, `bootError` is non-nil and
/// the UI should render an error state rather than the normal app.
@MainActor
final class AppEnvironment: ObservableObject {
    let settings = AppSettings.shared
    let vault: Vault
    let store: MemoryStore
    let embedder: Embedder
    let search: SearchService
    let activeAppWatcher = ActiveAppWatcher()

    @Published var countsByType: [MemoryType: Int] = [:]
    @Published var recentMemories: [Memory] = []
    @Published var bootError: String? = nil
    @Published var lastToast: String? = nil

    /// Build the full environment from disk. Returns nil only if every fallback
    /// has failed (extremely unlikely — missing Documents directory, sandbox
    /// denial, disk full).
    static func boot() async -> AppEnvironment? {
        let settings = AppSettings.shared
        do {
            let vault = try Vault(rootURL: settings.vaultURL)
            let embedder = Embedder()
            let store = try await MemoryStore(path: vault.sqliteURL, dimension: embedder.dimension)
            return await AppEnvironment(vault: vault, store: store, embedder: embedder)
        } catch {
            return await AppEnvironment(failureMessage: "Failed to open vault: \(error.localizedDescription)")
        }
    }

    private init(vault: Vault, store: MemoryStore, embedder: Embedder) async {
        self.vault = vault
        self.store = store
        self.embedder = embedder
        self.search = SearchService(store: store, embedder: embedder)
        await self.refresh()
    }

    /// Degraded constructor. Creates an in-memory store so the rest of the app
    /// doesn't have to handle optionals everywhere. Save/search will appear to
    /// work inside the running process but nothing persists.
    private init(failureMessage: String) async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mardi-error-\(UUID().uuidString).sqlite")
        let embedder = Embedder()
        let safeStore: MemoryStore
        do {
            safeStore = try await MemoryStore(path: tmp, dimension: embedder.dimension)
        } catch {
            // Last resort — this really shouldn't happen.
            fatalError("Cannot open even a temporary store: \(error)")
        }
        let safeVault = (try? Vault(rootURL: tmp.deletingLastPathComponent())) ??
            (try! Vault(rootURL: FileManager.default.temporaryDirectory))
        self.vault = safeVault
        self.store = safeStore
        self.embedder = embedder
        self.search = SearchService(store: safeStore, embedder: embedder)
        self.bootError = failureMessage
    }

    // MARK: - Public API for views

    func refresh() async {
        do {
            let counts = try await store.countsByType()
            let recent = try await store.all(limit: 40)
            self.countsByType = counts
            self.recentMemories = recent
        } catch {
            self.bootError = error.localizedDescription
        }
    }

    func save(_ memory: Memory, autoEnrich: Bool = true) async -> Memory? {
        let enriched: Memory
        if autoEnrich && settings.hasAPIKey {
            let tagger = Tagger(provider: settings.buildProvider())
            enriched = await tagger.enrich(memory)
        } else {
            var m = memory
            if m.title.isEmpty {
                let fb = TaggingPrompt.fallback(for: m)
                m.title = fb.title
                if m.tags.isEmpty { m.tags = fb.tags }
                m.summary = fb.summary
            }
            enriched = m
        }

        do {
            let written = try vault.write(enriched)
            let embed = embedder.embed(
                [written.title, written.tags.joined(separator: " "), written.body].joined(separator: "\n")
            )
            try await store.upsert(written, embedding: embed)
            await refresh()
            lastToast = MardiVoice.savedTo(written.type)
            return written
        } catch {
            self.bootError = "Save failed: \(error.localizedDescription)"
            return nil
        }
    }

    func delete(_ memory: Memory) async {
        do {
            try vault.delete(memory)
            try await store.delete(id: memory.id)
            await refresh()
        } catch {
            self.bootError = "Delete failed: \(error.localizedDescription)"
        }
    }
}
