import Foundation
import SwiftData

@Model
final class FlashCard {
    var targetWord: String
    var pronunciation: String?
    var nativeTranslation: String
    var exampleSentence: String?
    var sourceThumbnailData: Data?
    var sourceRaw: String
    var srsState: SRSState
    var language: Language?
    var addedAt: Date = Date.now
    var isPriority: Bool = false

    init(
        targetWord: String,
        pronunciation: String? = nil,
        nativeTranslation: String,
        exampleSentence: String? = nil,
        sourceThumbnailData: Data? = nil,
        source: CardSource = .manual,
        language: Language? = nil
    ) {
        self.targetWord = targetWord
        self.pronunciation = pronunciation
        self.nativeTranslation = nativeTranslation
        self.exampleSentence = exampleSentence
        self.sourceThumbnailData = sourceThumbnailData
        self.sourceRaw = source.rawValue
        self.srsState = SRSState()
        self.language = language
    }

    var source: CardSource {
        get { CardSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var isDueToday: Bool {
        srsState.nextReview <= .now
    }
}
