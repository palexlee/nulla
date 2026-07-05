import Foundation
import FoundationModels

@MainActor
final class AIService {
    static let shared = AIService()
    private var session: LanguageModelSession?

    func generateExampleSentence(word: String, languageCode: String, level: CEFRLevel) async -> String? {
        guard SystemLanguageModel.default.availability == .available else { return nil }
        if session == nil { session = LanguageModelSession() }
        let prompt = """
        Generate one short example sentence in \(languageName(for: languageCode)) using the word "\(word)".
        Appropriate for a \(level.description) learner (CEFR \(level.label)).
        Reply with only the sentence.
        """
        return try? await session?.respond(to: prompt).content
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func curateWords(_ words: [String], languageCode: String, level: CEFRLevel, count: Int = 5) async -> [String] {
        guard !words.isEmpty else { return [] }
        guard SystemLanguageModel.default.availability == .available else { return Array(words.prefix(count)) }
        if session == nil { session = LanguageModelSession() }
        let wordList = words.prefix(30).joined(separator: ", ")
        let prompt = """
        From this list of \(languageName(for: languageCode)) words/phrases: \(wordList)
        Select the \(count) most useful vocabulary items for a \(level.description) learner (CEFR \(level.label)).
        Reply with only the selected words separated by commas.
        """
        guard let response = try? await session?.respond(to: prompt).content else {
            return Array(words.prefix(count))
        }
        let curated = response
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return curated.isEmpty ? Array(words.prefix(count)) : curated
    }

    private func languageName(for code: String) -> String {
        switch code {
        case "zh-Hans": "Mandarin Chinese (Simplified)"
        case "de": "German"
        case "de-CH": "Swiss German (Zürichdeutsch)"
        default: code
        }
    }
}
