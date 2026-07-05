import Foundation

struct SRSService {
    static func schedule(state: inout SRSState, rating: ReviewRating) {
        let now = Date.now

        if state.reps == 0 {
            switch rating {
            case .again:
                state.stability = 0
                state.nextReview = Calendar.current.date(byAdding: .minute, value: 10, to: now)!
            case .hard:
                state.stability = 1
                state.nextReview = Calendar.current.date(byAdding: .day, value: 1, to: now)!
            case .good:
                state.stability = 3
                state.nextReview = Calendar.current.date(byAdding: .day, value: 3, to: now)!
            case .easy:
                state.stability = 7
                state.nextReview = Calendar.current.date(byAdding: .day, value: 7, to: now)!
            }
        } else {
            switch rating {
            case .again:
                state.lapses += 1
                state.difficulty = min(state.difficulty + 0.2, 1.0)
                state.stability = max(state.stability * 0.5, 0.5)
                state.nextReview = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
            case .hard:
                state.difficulty = min(state.difficulty + 0.1, 1.0)
                state.stability = max(state.stability * 1.2, 1.0)
                let interval = max(state.stability * 0.8, 1.0)
                state.nextReview = Calendar.current.date(byAdding: .day, value: Int(interval), to: now)!
            case .good:
                let factor = 1.0 + max(1.0 - state.difficulty, 0.1)
                state.stability = max(state.stability * factor, 1.0)
                state.nextReview = Calendar.current.date(byAdding: .day, value: Int(state.stability), to: now)!
            case .easy:
                state.difficulty = max(state.difficulty - 0.05, 0.1)
                let factor = 2.0 + max(1.0 - state.difficulty, 0.1)
                state.stability = max(state.stability * factor, 1.0)
                state.nextReview = Calendar.current.date(byAdding: .day, value: Int(state.stability), to: now)!
            }
        }

        state.reps += 1
        state.lastReview = now
    }

    static func nextIntervalDescription(for state: SRSState, rating: ReviewRating) -> String {
        var copy = state
        schedule(state: &copy, rating: rating)
        let interval = copy.nextReview.timeIntervalSinceNow
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }
}
