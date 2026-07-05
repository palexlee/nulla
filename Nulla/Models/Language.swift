import Foundation
import SwiftData

@Model
final class Language {
    var code: String
    var displayName: String
    var flag: String
    var levelRaw: Int

    // Streak tracking — powers the Home streak card and session-complete screen.
    var streak: Int = 0
    var lastStudied: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \FlashCard.language)
    var cards: [FlashCard] = []
    var addedAt: Date = Date.now

    init(code: String, displayName: String, flag: String, level: CEFRLevel = .a0) {
        self.code = code
        self.displayName = displayName
        self.flag = flag
        self.levelRaw = level.rawValue
    }

    var level: CEFRLevel {
        get { CEFRLevel(rawValue: levelRaw) ?? .a0 }
        set { levelRaw = newValue.rawValue }
    }

    var dueCards: [FlashCard] {
        cards.filter { $0.isDueToday }
    }

    var dueCount: Int { dueCards.count }

    /// Call once when a review session finishes. Bumps the streak on a fresh day,
    /// keeps it if already studied today, resets to 1 after a missed day.
    func registerStudySession(now: Date = .now) {
        let cal = Calendar.current
        if let last = lastStudied {
            if cal.isDateInToday(last) { return }                 // already counted today
            streak = cal.isDateInYesterday(last) ? streak + 1 : 1  // continue or reset
        } else {
            streak = 1
        }
        lastStudied = now
    }
}
