//
//  Personality.swift
//  Nulla — the calibrated voice
//
//  A warm smart-aleck: it teases the *situation*, never insults the learner.
//  Wire the dial with:  @AppStorage("personality") private var personalityRaw = Personality.full.rawValue
//  then:  let copy = Copy(personality: Personality(rawValue: personalityRaw) ?? .full, reviewed: n)
//

import Foundation

enum Personality: String, CaseIterable, Identifiable {
    case off, dry, full
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off:  return "Off"
        case .dry:  return "Dry"
        case .full: return "Full"
        }
    }
}

struct Copy {
    var personality: Personality
    var reviewed: Int = 0

    var greeting: String {
        switch personality {
        case .off:  return "Ready to review?"
        case .dry:  return "Back for more? Respectable."
        case .full: return "Oh good, you're back. Let's make that brain useful."
        }
    }

    var sessionTitle: String {
        switch personality {
        case .off:  return "Session complete"
        case .dry:  return "\(reviewed) down. Respectable work."
        case .full: return "\(reviewed) down. Your brain is now marginally more employable abroad."
        }
    }

    var sessionSub: String {
        switch personality {
        case .off:  return "Nice work. Come back tomorrow to keep your streak going."
        case .dry:  return "Same time tomorrow keeps the streak alive."
        case .full: return "Same time tomorrow — or the streak gets awkward."
        }
    }

    var caughtUpTitle: String {
        switch personality {
        case .off:  return "All caught up"
        case .dry:  return "Nothing due. Enjoy the quiet."
        case .full: return "Nothing due. Suspicious, but I'll allow it."
        }
    }

    var caughtUpSub: String {
        switch personality {
        case .off:  return "Nothing due right now. Your next batch unlocks in about 5 hours."
        case .dry:  return "Go outside — the words will keep."
        case .full: return "Go outside. The words will keep. Next batch in about 5 hours."
        }
    }

    var wrong: String {
        switch personality {
        case .off:  return "Not quite — we'll show this one again shortly."
        case .dry:  return "Close-ish. Back into the pile it goes."
        case .full: return "Bold guess. Wrong, but bold. See you in a minute."
        }
    }

    /// Preview line shown in Settings
    var sample: String {
        switch personality {
        case .off:  return "Session complete. Nice work today."
        case .dry:  return "Back for more? Respectable."
        case .full: return "\u{201C}Twelve down. Your brain is now marginally more employable abroad.\u{201D}"
        }
    }
}
