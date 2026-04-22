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
    let agent: MardiAgentWorkspace
    let activeAppWatcher = ActiveAppWatcher()

    @Published var countsByType: [MemoryType: Int] = [:]
    @Published var countsByFolder: [String: Int] = [:]
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
            let store = try await MemoryStore(path: vault.sqliteURL)
            try await store.setup()
            return await AppEnvironment(vault: vault, store: store, embedder: embedder)
        } catch {
            return await AppEnvironment(failureMessage: "Failed to open vault: \(Self.describe(error))")
        }
    }

    private init(vault: Vault, store: MemoryStore, embedder: Embedder) async {
        self.vault = vault
        self.store = store
        self.embedder = embedder
        self.search = SearchService(store: store, embedder: embedder)
        self.agent = MardiAgentWorkspace(vault: vault, settings: settings, search: self.search)
        await self.replayPendingMemories()
        await self.importVaultMemories()
        await self.refresh()
        await self.agent.load()
    }

    /// Degraded constructor. Creates an in-memory store so the rest of the app
    /// doesn't have to handle optionals everywhere. Save/search will appear to
    /// work inside the running process but nothing persists.
    private init(failureMessage: String) async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mardi-error-\(UUID().uuidString).sqlite")
        let embedder = Embedder()
        let safeStore: MemoryStore
        do {
            safeStore = try await MemoryStore(path: tmp)
            try await safeStore.setup()
        } catch {
            fatalError("Cannot open even a temporary store: \(error)")
        }
        let safeVault = (try? Vault(rootURL: tmp.deletingLastPathComponent())) ??
            (try! Vault(rootURL: FileManager.default.temporaryDirectory))
        self.vault = safeVault
        self.store = safeStore
        self.embedder = embedder
        self.search = SearchService(store: safeStore, embedder: embedder)
        self.agent = MardiAgentWorkspace(vault: safeVault, settings: settings, search: self.search)
        self.bootError = failureMessage
    }

    // MARK: - Public API for views

    func refresh() async {
        do {
            let counts = try await store.countsByType()
            let folderCounts = try await store.countsByFolder()
            let recent = try await store.all(limit: 40)
            self.countsByType = counts
            self.countsByFolder = folderCounts
            self.recentMemories = recent
        } catch {
            self.bootError = Self.describe(error)
        }
    }

    func save(_ capture: RawCapture, autoEnrich: Bool = true) async -> Memory? {
        do {
            let normalized = await normalize(capture, autoEnrich: autoEnrich)
            let written = try await persistNormalized(normalized)
            await refresh()
            lastToast = MardiVoice.savedTo(written.type)
            return written
        } catch {
            self.bootError = "Save failed: \(Self.describe(error))"
            return nil
        }
    }

    func save(_ memory: Memory, autoEnrich: Bool = true) async -> Memory? {
        let capture = RawCapture(
            id: memory.id,
            requestedType: memory.type,
            title: memory.title,
            body: memory.body,
            tags: memory.tags,
            folder: memory.folder,
            sourceApp: memory.sourceApp,
            sourceURL: memory.sourceURL,
            created: memory.created
        )
        return await save(capture, autoEnrich: autoEnrich)
    }

    func delete(_ memory: Memory) async {
        do {
            try vault.delete(memory)
            try await store.delete(id: memory.id)
            await refresh()
        } catch {
            self.bootError = "Delete failed: \(Self.describe(error))"
        }
    }

    func update(_ memory: Memory, refreshAfter: Bool = true) async -> Memory? {
        do {
            let written = try await persistNormalized(memory)
            if refreshAfter {
                await refresh()
                lastToast = "Updated \(written.type.displayName.lowercased())"
            }
            return written
        } catch {
            self.bootError = "Update failed: \(Self.describe(error))"
            return nil
        }
    }

    func renameFolder(from oldName: String, to newName: String) async -> Bool {
        let target = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !target.isEmpty, source != target else { return false }

        do {
            let memories = try await store.all(folder: source, limit: 10_000)
            guard !memories.isEmpty else { return true }
            for memory in memories {
                var updated = memory
                updated.folder = target
                _ = await update(updated, refreshAfter: false)
            }
            await refresh()
            lastToast = "Renamed folder to \(target)"
            return true
        } catch {
            self.bootError = "Rename failed: \(Self.describe(error))"
            return false
        }
    }

    private static func describe(_ error: any Error) -> String {
        let ns = error as NSError
        let localized = ns.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if localized != "The operation couldn’t be completed." && localized != "The operation could not be completed." {
            return localized
        }
        return String(describing: error)
    }

    private func normalize(_ capture: RawCapture, autoEnrich: Bool) async -> Memory {
        let provider = (autoEnrich && settings.hasAPIKey) ? settings.buildProvider() : nil
        let normalizer = CaptureNormalizer(provider: provider)
        return await normalizer.normalize(capture, allowLLM: autoEnrich && settings.hasAPIKey)
    }

    private func persistNormalized(_ memory: Memory) async throws -> Memory {
        try vault.stagePending(memory)
        let written = try vault.write(memory)
        let embed = embedder.embed(
            [written.title, written.tags.joined(separator: " "), written.body].joined(separator: "\n")
        )
        try await store.upsert(written, embedding: embed)
        try vault.removePending(id: written.id)
        return written
    }

    private func replayPendingMemories() async {
        let pending: [Memory]
        do {
            pending = try vault.pendingMemories()
        } catch {
            self.bootError = "Pending replay failed: \(Self.describe(error))"
            return
        }

        guard !pending.isEmpty else { return }
        for memory in pending {
            do {
                _ = try await persistNormalized(memory)
            } catch {
                self.bootError = "Pending replay failed: \(Self.describe(error))"
                return
            }
        }
    }

    private func importVaultMemories() async {
        let indexedPaths: Set<String>
        do {
            indexedPaths = try await store.indexedMarkdownPaths()
        } catch {
            self.bootError = "Vault import failed: \(Self.describe(error))"
            return
        }

        let vaultMemories: [Memory]
        do {
            vaultMemories = try vault.allMemories()
        } catch {
            self.bootError = "Vault import failed: \(Self.describe(error))"
            return
        }

        let missing = vaultMemories.filter { !indexedPaths.contains($0.markdownPath) }
        guard !missing.isEmpty else { return }

        for memory in missing {
            do {
                let embedding = embedder.embed(
                    [memory.title, memory.tags.joined(separator: " "), memory.body].joined(separator: "\n")
                )
                try await store.upsert(memory, embedding: embedding)
            } catch {
                self.bootError = "Vault import failed: \(Self.describe(error))"
                return
            }
        }

        lastToast = "Imported \(missing.count) existing memories"
    }

}
