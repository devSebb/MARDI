import Foundation
import SwiftUI

enum MemoryType: String, Codable, CaseIterable, Identifiable, Hashable {
    case url
    case snippet
    case ssh
    case prompt
    case signature
    case reply
    case note
    case select

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .url: "URL"
        case .snippet: "Snippet"
        case .ssh: "SSH"
        case .prompt: "Prompt"
        case .signature: "Signature"
        case .reply: "Reply"
        case .note: "Note"
        case .select: "Select"
        }
    }

    var pluralName: String {
        switch self {
        case .url: "URLs"
        case .snippet: "Snippets"
        case .ssh: "SSH"
        case .prompt: "Prompts"
        case .signature: "Signatures"
        case .reply: "Replies"
        case .note: "Notes"
        case .select: "Select"
        }
    }

    var folderName: String { "_" + rawValue + "s" }

    var symbol: String {
        switch self {
        case .url: "link"
        case .snippet: "text.alignleft"
        case .ssh: "terminal"
        case .prompt: "sparkles"
        case .signature: "signature"
        case .reply: "arrowshape.turn.up.left"
        case .note: "note.text"
        case .select: "viewfinder"
        }
    }

}
