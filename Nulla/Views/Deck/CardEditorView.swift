import SwiftUI
import SwiftData
import UIKit

struct CardEditorView: View {
    let cardModel: FlashCard
    let language: Language

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var wordText: String
    @State private var pronunciationText: String
    @State private var translationText: String
    @State private var exampleText: String
    @State private var isGeneratingSentence = false
    @State private var isShowingDeleteConfirmation = false

    init(cardModel: FlashCard, language: Language) {
        self.cardModel = cardModel
        self.language = language
        _wordText = State(initialValue: cardModel.targetWord)
        _pronunciationText = State(initialValue: cardModel.pronunciation ?? "")
        _translationText = State(initialValue: cardModel.nativeTranslation)
        _exampleText = State(initialValue: cardModel.exampleSentence ?? "")
    }

    private var canSave: Bool {
        !wordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !translationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.surface2)
                        .frame(width: 40, height: 5)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 22)

                    Text("Edit card")
                        .manrope(22, .heavy).foregroundStyle(Theme.ink)
                        .padding(.bottom, 20)

                    if let data = cardModel.sourceThumbnailData, let uiImage = UIImage(data: data) {
                        imageBanner(uiImage)
                            .padding(.bottom, 18)
                    }

                    fieldSection("TARGET WORD") {
                        styledTextField("Word in \(language.displayName)", text: $wordText, bold: true)
                    }
                    fieldSection("PRONUNCIATION") {
                        styledTextField("optional", text: $pronunciationText)
                    }
                    fieldSection("TRANSLATION") {
                        styledTextField("English translation", text: $translationText)
                    }
                    fieldSection("EXAMPLE SENTENCE") {
                        styledTextField("optional", text: $exampleText)
                        if !wordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            generateButton
                                .padding(.top, 10)
                        }
                    }
                    .padding(.bottom, 22)

                    footerButtons
                }
                .padding(24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .confirmationDialog("Delete Card?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteCard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func imageBanner(_ uiImage: UIImage) -> some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 5) {
                Text("📷").font(.system(size: 10))
                Text("Scanned photo")
                    .manrope(10.5, .bold).foregroundStyle(Theme.card)
            }
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Color.black.opacity(0.55), in: Capsule())
            .padding(9)
        }
    }

    @ViewBuilder
    private func fieldSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .manrope(11, .bold).tracking(0.4).foregroundStyle(Theme.muted)
            content()
        }
        .padding(.bottom, 14)
    }

    private func styledTextField(_ placeholder: String, text: Binding<String>, bold: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .manrope(bold ? 16 : 15, bold ? .bold : .medium)
            .foregroundStyle(Theme.ink)
            .tint(Theme.green)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.surface2, lineWidth: 1.5)
            )
    }

    private var generateButton: some View {
        Button {
            Task { await generateSentence() }
        } label: {
            Group {
                if isGeneratingSentence {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.8)
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
        .disabled(isGeneratingSentence)
    }

    private var footerButtons: some View {
        HStack(spacing: 10) {
            Button {
                isShowingDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.onCoral)
                    .frame(width: 52, height: 52)
                    .background(Theme.coral, in: RoundedRectangle(cornerRadius: Theme.rPill))
            }
            .buttonStyle(.plain)

            Button {
                saveCard()
            } label: {
                Text("Save changes")
                    .manrope(14, .bold)
                    .foregroundStyle(canSave ? Theme.onGreen : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSave ? Theme.green : Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rPill))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
    }

    private func saveCard() {
        cardModel.targetWord = wordText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedP = pronunciationText.trimmingCharacters(in: .whitespacesAndNewlines)
        cardModel.pronunciation = trimmedP.isEmpty ? nil : trimmedP
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
