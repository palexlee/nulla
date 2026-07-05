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
        NavigationStack {
            List {
                Section {
                    ForEach($drafts) { $draft in
                        CardDraftRow(draft: $draft, language: language)
                    }
                } header: {
                    Text("\(drafts.count) word\(drafts.count == 1 ? "" : "s") to add")
                }
            }
            .navigationTitle("Review Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save all") { saveAll() }
                        .disabled(isSaving || drafts.isEmpty)
                }
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

struct CardDraftRow: View {
    @Binding var draft: CardDraft
    let language: Language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.word)
                .font(.headline)

            if draft.translation.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.75)
                    Text("Translating…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                TextField("Translation", text: $draft.translation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if draft.exampleSentence.isEmpty {
                Button {
                    Task { await generateSentence() }
                } label: {
                    if draft.isGeneratingSentence {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Generating…").foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    } else {
                        Label("Generate example sentence", systemImage: "sparkles")
                            .font(.caption)
                    }
                }
                .disabled(draft.isGeneratingSentence)
            } else {
                TextField("Example sentence", text: $draft.exampleSentence, axis: .vertical)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(2, reservesSpace: false)
            }
        }
        .padding(.vertical, 4)
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
