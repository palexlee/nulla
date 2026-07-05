import SwiftUI
import SwiftData

struct DeckView: View {
    let language: Language
    @Environment(\.modelContext) private var context

    @State private var searchText = ""
    @State private var showAddCard = false
    @State private var showCamera = false
    @State private var sourceFilter: CardSource? = nil
    @State private var editingCard: FlashCard? = nil

    var filteredCards: [FlashCard] {
        language.cards
            .filter { card in
                (sourceFilter == nil || card.source == sourceFilter) &&
                (searchText.isEmpty ||
                 card.targetWord.localizedCaseInsensitiveContains(searchText) ||
                 card.nativeTranslation.localizedCaseInsensitiveContains(searchText))
            }
            .sorted { $0.addedAt > $1.addedAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if language.cards.isEmpty {
                    emptyDeckView
                } else {
                    cardList
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("\(language.flag) \(language.displayName)")
            .searchable(text: $searchText, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAddCard = true
                        } label: {
                            Label("Add manually", systemImage: "plus.circle")
                        }
                        Button {
                            showCamera = true
                        } label: {
                            Label("Scan with camera", systemImage: "camera")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button("All") { sourceFilter = nil }
                        ForEach(CardSource.allCases, id: \.rawValue) { source in
                            Button {
                                sourceFilter = source
                            } label: {
                                Label(source.label, systemImage: source.icon)
                            }
                        }
                    } label: {
                        Image(systemName: sourceFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddCard) {
                AddCardView(language: language)
            }
            .sheet(isPresented: $showCamera) {
                CameraView(language: language)
            }
            .sheet(item: $editingCard) { card in
                CardEditorView(cardModel: card, language: language)
            }
        }
    }

    private var emptyDeckView: some View {
        ContentUnavailableView {
            Label("No cards yet", systemImage: "rectangle.stack.badge.plus")
        } description: {
            Text("Add your first card manually or scan text with your camera.")
        } actions: {
            Button("Add manually") { showAddCard = true }.buttonStyle(.borderedProminent)
            Button("Scan with camera") { showCamera = true }.buttonStyle(.bordered)
        }
    }

    private var cardList: some View {
        List {
            Section {
                ForEach(filteredCards) { card in
                    CardRow(card: card, language: language)
                        .listRowBackground(Theme.card)
                        .onTapGesture { editingCard = card }
                        .contextMenu {
                            Button {
                                editingCard = card
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                context.delete(card)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("All Cards").manrope(12, .bold).foregroundStyle(Theme.muted)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct CardRow: View {
    let card: FlashCard
    let language: Language

    var body: some View {
        HStack(spacing: 12) {
            if let data = card.sourceThumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: card.source.icon)
                    .font(.title3)
                    .foregroundStyle(Theme.green)
                    .frame(width: 44, height: 44)
                    .background(Theme.mint, in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(card.targetWord).manrope(16, .bold).foregroundStyle(Theme.ink)
                if !card.nativeTranslation.isEmpty {
                    Text(card.nativeTranslation)
                        .manrope(13, .medium)
                        .foregroundStyle(Theme.muted)
                }
            }

            Spacer()

            if card.isDueToday {
                Text("DUE")
                    .manrope(10.5, .bold)
                    .foregroundStyle(Theme.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.mintChip, in: Capsule())
            } else {
                Text(card.srsState.nextReview, style: .relative)
                    .manrope(11, .medium)
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.vertical, 4)
    }
}
