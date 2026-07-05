import SwiftUI
import SwiftData
import Translation

struct CardDraft: Identifiable {
    let id = UUID()
    var word: String
    var translation: String = ""
    var exampleSentence: String = ""
    var isGeneratingSentence: Bool = false
}

struct CameraWordListView: View {
    let words: [String]
    let language: Language
    let thumbnailData: Data?
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var drafts: [CardDraft] = []
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 6)

                Text("\(drafts.count) word\(drafts.count == 1 ? "" : "s") · translations auto-filled")
                    .manrope(12, .semibold).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($drafts) { $draft in
                            DraftCardView(draft: $draft, language: language)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                addButton
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
        }
        .onAppear {
            drafts = words.map { CardDraft(word: $0) }
            triggerTranslation()
        }
        .translationTask(translationConfig) { session in
            let requests = drafts.map { TranslationSession.Request(sourceText: $0.word) }
            guard !requests.isEmpty,
                  let responses = try? await session.translations(from: requests) else { return }
            for (index, response) in responses.enumerated() where index < drafts.count {
                drafts[index].translation = response.targetText
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Text("‹ Back").manrope(13, .semibold).foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Review cards")
                .manrope(15, .heavy).foregroundStyle(Theme.ink)
            Spacer()
            Button { saveAll() } label: {
                Text("Save all").manrope(13, .bold).foregroundStyle(Theme.green)
            }
            .buttonStyle(.plain)
            .disabled(isSaving || drafts.isEmpty)
        }
    }

    private var addButton: some View {
        let count = drafts.count
        return Button { saveAll() } label: {
            Text("Add \(count) card\(count == 1 ? "" : "s") to deck")
                .manrope(14, .bold)
                .foregroundStyle(drafts.isEmpty ? Theme.muted : Theme.onGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    drafts.isEmpty ? Theme.surface : Theme.green,
                    in: RoundedRectangle(cornerRadius: Theme.rPill)
                )
        }
        .buttonStyle(.plain)
        .disabled(isSaving || drafts.isEmpty)
    }

    private func triggerTranslation() {
        translationConfig = TranslationSession.Configuration(
            source: Locale.Language(identifier: language.code),
            target: Locale.Language(identifier: "en")
        )
        translationConfig?.invalidate()
    }

    private func saveAll() {
        isSaving = true
        for draft in drafts {
            let card = FlashCard(
                targetWord: draft.word,
                nativeTranslation: draft.translation,
                exampleSentence: draft.exampleSentence.isEmpty ? nil : draft.exampleSentence,
                sourceThumbnailData: thumbnailData,
                source: .camera,
                language: language
            )
            context.insert(card)
            language.cards.append(card)
        }
        onSaved()
        dismiss()
    }
}

struct DraftCardView: View {
    @Binding var draft: CardDraft
    let language: Language

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(draft.word)
                .manrope(20, .heavy).foregroundStyle(Theme.ink)
                .padding(.bottom, 11)

            Rectangle()
                .fill(Theme.surface2)
                .frame(height: 1)
                .padding(.bottom, 11)

            if draft.translation.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.75)
                    Text("Translating…")
                        .manrope(14, .semibold).foregroundStyle(Theme.faint)
                }
                .padding(.bottom, 8)
            } else {
                Text(draft.translation)
                    .manrope(14, .semibold).foregroundStyle(Theme.faint)
                    .padding(.bottom, draft.exampleSentence.isEmpty ? 0 : 11)
            }

            if draft.exampleSentence.isEmpty {
                generateButton
                    .padding(.top, draft.translation.isEmpty ? 8 : 0)
            } else {
                Text(draft.exampleSentence)
                    .manrope(13.5, .medium).italic().foregroundStyle(Theme.faint)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 17).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.rCard))
        .shadow(color: .black.opacity(0.04), radius: 9, y: 3)
    }

    private var generateButton: some View {
        Button {
            Task { await generateSentence() }
        } label: {
            Group {
                if draft.isGeneratingSentence {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.75)
                        Text("Generating…").manrope(12.5, .semibold).foregroundStyle(Theme.onLav)
                    }
                } else {
                    Text("✨ Generate example")
                        .manrope(12.5, .bold).foregroundStyle(Theme.onLav)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Theme.lavender, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(draft.isGeneratingSentence)
    }

    private func generateSentence() async {
        draft.isGeneratingSentence = true
        defer { draft.isGeneratingSentence = false }
        draft.exampleSentence = await AIService.shared.generateExampleSentence(
            word: draft.word,
            languageCode: language.code,
            level: language.level
        ) ?? ""
    }
}
