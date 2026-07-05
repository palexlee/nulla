import Foundation

struct SRSState: Codable, Equatable {
    var stability: Double = 0
    var difficulty: Double = 0.3
    var nextReview: Date = .now
    var reps: Int = 0
    var lapses: Int = 0
    var lastReview: Date?
}

enum CEFRLevel: Int, Codable, CaseIterable {
    case a0, a1, a2, b1, b2, c1, c2

    var label: String {
        ["A0", "A1", "A2", "B1", "B2", "C1", "C2"][rawValue]
    }

    var description: String {
        switch self {
        case .a0: "Complete beginner"
        case .a1: "Beginner"
        case .a2: "Elementary"
        case .b1: "Intermediate"
        case .b2: "Upper intermediate"
        case .c1: "Advanced"
        case .c2: "Proficient"
        }
    }
}

enum CardSource: String, Codable, CaseIterable {
    case manual, camera, conversation

    var label: String {
        switch self {
        case .manual: "Manual"
        case .camera: "Camera"
        case .conversation: "Conversation"
        }
    }

    var icon: String {
        switch self {
        case .manual: "plus.circle"
        case .camera: "camera"
        case .conversation: "bubble.left.and.bubble.right"
        }
    }
}

enum ReviewRating: Int, CaseIterable {
    case again = 1, hard = 2, good = 3, easy = 4

    var label: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    var color: String {
        switch self {
        case .again: "red"
        case .hard: "orange"
        case .good: "green"
        case .easy: "blue"
        }
    }
}
