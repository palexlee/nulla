import SwiftUI
import SwiftData
import Translation

struct AddCardView: View {
    let language: Language
    var prefillWord: String? = nil
    var prefillForeignWord: String? = nil
    var source: CardSource = .manual
    var sourceThumbnailData: Data? = nil
    var onSaved: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var englishWord = ""
    @State private var foreignWord = ""
    @State private var pronunciation = ""
    @State private var exampleSentence = ""
    @State private var isGeneratingSentence = false
    @State private var isTranslating = false
    @State private var translationConfig: TranslationSession.Configuration?

    var canSave: Bool {
        !englishWord.trimmingCharacters(in: .whitespaces).isEmpty &&
        !foreignWord.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Word in English") {
                    TextField("e.g. apple", text: $englishWord)
                        .autocorrectionDisabled()
                        .onChange(of: englishWord) { _, new in
                            if new.count > 1 { triggerTranslation() }
                        }
                }

                Section("In \(language.displayName)") {
                    if foreignWord.isEmpty && isTranslating {
                        HStack {
                            Text("Translating…")
                                .foregroundStyle(.secondary)
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        TextField("Translation", text: $foreignWord)
                            .autocorrectionDisabled()
                    }

                    TextField("Pronunciation (optional)", text: $pronunciation)
                        .autocorrectionDisabled()
                }

                Section("Example sentence (optional)") {
                    if exampleSentence.isEmpty {
                        Button {
                            Task { await generateSentence() }
                        } label: {
                            if isGeneratingSentence {
                                HStack { ProgressView(); Text("Generating…").foregroundStyle(.secondary) }
                            } else {
                                Label("Generate with AI", systemImage: "sparkles")
                            }
                        }
                        .disabled(foreignWord.isEmpty || isGeneratingSentence)
                    } else {
                        TextField("Example sentence", text: $exampleSentence, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                }
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCard() }
                        .disabled(!canSave)
                }
            }
            .translationTask(translationConfig) { session in
                guard !englishWord.isEmpty else { return }
                isTranslating = true
                defer { isTranslating = false }
                if let result = try? await session.translate(englishWord) {
                    foreignWord = result.targetText
                }
            }
            .onAppear {
                if let foreignPrefill = prefillForeignWord, !foreignPrefill.isEmpty {
                    foreignWord = foreignPrefill
                    if let engPrefill = prefillWord, !engPrefill.isEmpty {
                        englishWord = engPrefill
                    }
                } else if let word = prefillWord, englishWord.isEmpty {
                    englishWord = word
                    triggerTranslation()
                }
            }
        }
    }

    private func triggerTranslation() {
        translationConfig = TranslationSession.Configuration(
            source: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: language.code)
        )
        translationConfig?.invalidate()
    }

    private func generateSentence() async {
        isGeneratingSentence = true
        defer { isGeneratingSentence = false }
        exampleSentence = await AIService.shared.generateExampleSentence(
            word: foreignWord,
            languageCode: language.code,
            level: language.level
        ) ?? ""
    }

    private func saveCard() {
        let card = FlashCard(
            targetWord: foreignWord.trimmingCharacters(in: .whitespaces),
            pronunciation: pronunciation.isEmpty ? nil : pronunciation,
            nativeTranslation: englishWord.trimmingCharacters(in: .whitespaces),
            exampleSentence: exampleSentence.isEmpty ? nil : exampleSentence,
            sourceThumbnailData: sourceThumbnailData,
            source: source,
            language: language
        )
        context.insert(card)
        language.cards.append(card)
        onSaved?()
        dismiss()
    }
}
