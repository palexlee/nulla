import SwiftUI
import SwiftData

struct CardEditorView: View {
    let cardModel: FlashCard
    let language: Language

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var wordText: String
    @State private var translationText: String
    @State private var exampleText: String
    @State private var isGeneratingSentence = false
    @State private var isShowingDeleteConfirmation = false

    init(cardModel: FlashCard, language: Language) {
        self.cardModel = cardModel
        self.language = language
        _wordText = State(initialValue: cardModel.targetWord)
        _translationText = State(initialValue: cardModel.nativeTranslation)
        _exampleText = State(initialValue: cardModel.exampleSentence ?? "")
    }

    private var canSave: Bool {
        !wordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !translationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    TextField("Word in \(language.displayName)", text: $wordText)
                        .autocorrectionDisabled()
                }

                Section("Translation") {
                    TextField("English translation", text: $translationText)
                }

                Section("Example sentence (optional)") {
                    TextField("Example sentence", text: $exampleText, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)

                    Button {
                        Task { await generateSentence() }
                    } label: {
                        if isGeneratingSentence {
                            HStack {
                                ProgressView()
                                Text("Generating…").foregroundStyle(.secondary)
                            }
                        } else {
                            Label("Generate with AI", systemImage: "sparkles")
                        }
                    }
                    .disabled(wordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeneratingSentence)
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCard() }
                        .disabled(!canSave)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog("Delete Card?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteCard() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func saveCard() {
        cardModel.targetWord = wordText.trimmingCharacters(in: .whitespacesAndNewlines)
        cardModel.nativeTranslation = translationText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExample = exampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        cardModel.exampleSentence = trimmedExample.isEmpty ? nil : trimmedExample
        dismiss()
    }

    private func deleteCard() {
        modelContext.delete(cardModel)
        dismiss()
    }

    private func generateSentence() async {
        isGeneratingSentence = true
        defer { isGeneratingSentence = false }
        let word = wordText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        if let sentence = await AIService.shared.generateExampleSentence(
            word: word,
            languageCode: language.code,
            level: language.level
        ), !sentence.isEmpty {
            exampleText = sentence
        }
    }
}
