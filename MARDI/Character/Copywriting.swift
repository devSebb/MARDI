import Foundation

/// Centralised personality strings. Change here to tune Mardi's voice.
/// He is: helpful, concise, faintly wry, affectionate. Never chatty.
enum MardiVoice {
    static let firstGreeting = "Hi. I'm Mardi. I'll remember things for you."

    static let summonedPrompts: [String] = [
        "Save something?",
        "What's worth keeping?",
        "Point me at it.",
        "Got something for me?",
        "I'm listening.",
    ]

    static let emptyVault = "Nothing saved yet. Give me something."

    static let thinking = "Thinking…"

    static func savedTo(_ type: MemoryType) -> String {
        "Got it. Saved to \(type.pluralName)."
    }

    static let idleNudge = "Still here."
    static let sleepy = "Mm. Sleepy."

    static func errorGeneric(_ reason: String? = nil) -> String {
        if let r = reason, !r.isEmpty {
            return "Hm. \(r)"
        }
        return "Hm. Something didn't work."
    }

    static let selectModeIntro = "Drag a box. I'll read what's inside."
    static let selectModeCancel = "Never mind."

    static func randomSummon() -> String {
        summonedPrompts.randomElement() ?? "Save something?"
    }
}
