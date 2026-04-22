import Foundation
import SwiftUI
import Combine

@MainActor
final class MonsterViewModel: ObservableObject {
    @Published var mood: MardiMood = .idle
    @Published var speech: String = MardiVoice.randomSummon()
    @Published var mode: Mode = .root
    @Published var savingMessage: String? = nil
    @Published var errorMessage: String? = nil
    @Published var searchText: String = ""
    @Published var searchResults: [Memory] = []
    @Published var isSearching: Bool = false
    @Published var drawerExpanded: Bool = false
    @Published var drawerType: MemoryType? = nil

    unowned let env: AppEnvironment

    enum Mode: Equatable {
        case root
        case capture(type: MemoryType, prefill: CapturePrefill?)
        case search
    }

    init(env: AppEnvironment) {
        self.env = env
    }

    func onSummon() {
        mood = .summoned
        speech = env.settings.hasAPIKey ? MardiVoice.randomSummon()
                                        : "Set an API key in Settings first."
        mode = .root
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if mood == .summoned { mood = .idle }
        }
    }

    func onDismiss() {
        mood = .idle
        mode = .root
        searchText = ""
        searchResults = []
        drawerExpanded = false
        drawerType = nil
    }

    func cancelCapture() {
        mode = .root
        drawerExpanded = false
        drawerType = nil
    }

    // MARK: - Capture

    func beginCapture(type: MemoryType) {
        drawerType = type
        switch type {
        case .url:
            beginURLCapture()
        default:
            var pre = CapturePrefill()
            if type == .snippet || type == .note || type == .ssh || type == .prompt {
                if let clip = ClipboardReader.currentText() {
                    pre.body = clip
                }
            }
            pre.sourceApp = env.activeAppWatcher.frontmostBundleID
            mode = .capture(type: type, prefill: pre)
        }
    }

    func toggleDrawer(for type: MemoryType?) {
        guard let type else {
            drawerExpanded = false
            return
        }
        if drawerExpanded && drawerType == type {
            drawerExpanded = false
        } else {
            drawerType = type
            drawerExpanded = true
        }
    }

    private func beginURLCapture() {
        do {
            let res = try BrowserURLReader.readFromFrontmost()
            var pre = CapturePrefill()
            pre.title = res.title
            pre.body = res.url
            pre.sourceURL = res.url
            pre.sourceApp = res.bundleID
            mode = .capture(type: .url, prefill: pre)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            mood = .error
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                if mood == .error { mood = .idle; errorMessage = nil }
            }
        }
    }

    func submitCapture(title: String, body: String, tagsRaw: String, folder: String, type: MemoryType, prefill: CapturePrefill?) {
        let rawTags = tagsRaw
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let capture = RawCapture(
            requestedType: type,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body,
            tags: rawTags,
            folder: folder.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceApp: prefill?.sourceApp,
            sourceURL: prefill?.sourceURL ?? (type == .url ? body : nil)
        )

        mood = .thinking
        savingMessage = MardiVoice.thinking
        Task { @MainActor in
            if let saved = await env.save(capture) {
                mood = .success
                savingMessage = MardiVoice.savedTo(saved.type)
                try? await Task.sleep(nanoseconds: 900_000_000)
                mood = .idle
                savingMessage = nil
                mode = .root
            } else {
                mood = .error
                savingMessage = MardiVoice.errorGeneric(env.bootError)
            }
        }
    }

    // MARK: - Search

    func enterSearch() {
        mode = .search
        mood = .listening
        searchText = ""
        drawerExpanded = false
        drawerType = nil
        Task { await runSearch() }
    }

    func updateSearch(_ text: String) {
        searchText = text
        Task { await runSearch() }
    }

    private func runSearch() async {
        isSearching = true
        defer { isSearching = false }
        let ctxFilter = env.activeAppWatcher.context.searchFilter
        let typeFilter: MemoryType? = ctxFilter.count == 1 ? ctxFilter.first : nil
        do {
            let hits = try await env.search.search(query: searchText, type: typeFilter, k: 8)
            searchResults = hits
        } catch {
            searchResults = []
        }
    }
}
