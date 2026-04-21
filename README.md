# MARDI

A retro-futuristic macOS second-brain companion. Pull your cursor to the top-right corner and a little robot asks what you want to save — URL, snippet, SSH command, AI prompt, email signature, canned reply, free-form note, or OCR'd text from a screen region. Memories are auto-tagged by an LLM (Claude or OpenRouter) and stored in an Obsidian-compatible markdown vault. Recall through semantic + keyword search and a three-pane Obsidian-style dashboard.

> v0. Greenfield as of April 2026.

## Quick start (local)

### 1. Prerequisites

- **macOS 15+** (Sequoia or later)
- **Xcode 16+** (free on the Mac App Store)
- **Homebrew** (for `xcodegen`) — https://brew.sh/
- An **LLM API key** (either):
  - Anthropic — https://console.anthropic.com/
  - OpenRouter — https://openrouter.ai/keys

### 2. Generate the Xcode project

```bash
cd ~/Documents/Development/Projects/MARDI
brew install xcodegen        # one-time, skip if already installed
xcodegen generate
open MARDI.xcodeproj
```

### 3. Set the signing team

In Xcode, select the `MARDI` target → **Signing & Capabilities** → set **Team** to your personal Apple ID (free).

### 4. Run

`⌘R`.

On first launch:
1. Settings opens — pick your provider (Claude or OpenRouter), paste your API key, confirm vault path.
2. macOS asks about notifications — allow.
3. The MARDI menu bar icon appears. Pull your cursor to the top-right corner of the screen and dwell half a second → the robot pops in.
4. First time you save a URL from a specific browser → macOS will ask to allow MARDI to control it. Allow.
5. First time you use Select Mode → macOS will ask for Screen Recording. Allow.

### 5. Vault

Your memories live as plain markdown files at `~/Documents/MARDI-Vault/`. You can open that folder in Obsidian directly — MARDI writes Obsidian-compatible YAML frontmatter. MARDI-internal state lives in the hidden `.mardi/` subfolder.

## Keyboard shortcuts

| | |
|---|---|
| `⌘⇧M` | Global quick search (works from any app) |
| `⌘P` | Command palette (main window) |
| `⌘O` | Quick switcher — open memory by title (main window) |
| `⌘,` | Settings |
| `Esc` | Dismiss overlays |

## Architecture

See [the v0 plan](./docs/plan.md) for the full architecture write-up. Short version:

- Native Swift 6 + SwiftUI.
- Single SQLite DB (`~/Documents/MARDI-Vault/.mardi/mardi.sqlite`) with FTS5 + `sqlite-vec` for vectors + metadata tables.
- Local sentence embeddings via Apple's `NaturalLanguage` framework (`NLEmbedding.sentenceEmbedding`) — fully on-device, no model download required.
- LLM auto-tagging on save via `ClaudeProvider` or `OpenRouterProvider` (user-configurable).
- Obsidian-compatible markdown with YAML frontmatter.

## Permissions (minimal footprint)

| Permission | When prompted | Why |
|---|---|---|
| Automation | First URL save per browser | Read the current tab's URL via AppleScript |
| Screen Recording | First Select Mode use | Capture a dragged region |
| Notifications | First launch | "Saved ✓" toasts |

**Accessibility** and **Input Monitoring** are *not* requested. Hot corner detection uses polled mouse location, which doesn't need either.
