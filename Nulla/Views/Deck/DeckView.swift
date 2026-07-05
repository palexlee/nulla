import SwiftUI
import SwiftData

struct DeckView: View {
    let language: Language
    @Environment(\.modelContext) private var context

    @State private var searchText = ""
    @State private var showCamera = false
    @State private var showLanguagePicker = false
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
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                    searchBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 14)

                    filterChips
                        .padding(.horizontal, 24)
                        .padding(.bottom, 6)

                    cardListContent
                }
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(language: language)
        }
        .sheet(item: $editingCard) { card in
            CardEditorView(cardModel: card, language: language)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguageSwitcherSheet()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Button { showLanguagePicker = true } label: {
                    HStack(spacing: 4) {
                        Text("\(language.flag) \(language.displayName) · \(language.level.label)")
                            .manrope(12, .semibold).foregroundStyle(Theme.muted)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9)).foregroundStyle(Theme.muted)
                    }
                }
                .buttonStyle(.plain)
                Text("Your deck")
                    .manrope(26, .heavy).foregroundStyle(Theme.ink)
            }
            Spacer()
            Button { showCamera = true } label: {
                Text("+")
                    .manrope(28, .medium).foregroundStyle(Theme.onGreen)
                    .frame(width: 42, height: 42)
                    .background(Theme.green, in: Circle())
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Theme.faint)
            TextField("Search \(language.cards.count) cards", text: $searchText)
                .manrope(13, .medium)
                .foregroundStyle(Theme.ink)
                .tint(Theme.green)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rTile))
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            filterChip("All", value: nil)
            filterChip("Camera", value: .camera)
            filterChip("Manual", value: .manual)
            Spacer()
        }
    }

    private func filterChip(_ label: String, value: CardSource?) -> some View {
        let active = sourceFilter == value
        return Button { sourceFilter = value } label: {
            Text(label)
                .manrope(12, active ? .bold : .semibold)
                .foregroundStyle(active ? Theme.onGreen : Theme.muted)
                .padding(.horizontal, 15).padding(.vertical, 7)
                .background(active ? Theme.green : Theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cardListContent: some View {
        if language.cards.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 0) {
                ForEach(filteredCards) { card in
                    CardRow(card: card)
                        .padding(.horizontal, 24)
                        .contentShape(Rectangle())
                        .onTapGesture { editingCard = card }
                        .contextMenu {
                            Button { editingCard = card } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                context.delete(card)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    Rectangle()
                        .fill(Theme.surface2)
                        .frame(height: 1)
                        .padding(.leading, 24 + 44 + 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Text("No cards here yet.")
                .manrope(13.5, .semibold).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Text("Tap + to scan your first word.")
                .manrope(13, .medium).foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

struct CardRow: View {
    let card: FlashCard

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            wordInfo
            Spacer()
            dueInfo
        }
        .padding(.vertical, 11)
    }

    private var thumbnail: some View {
        Group {
            if let data = card.sourceThumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(String(card.targetWord.prefix(1)))
                    .manrope(17, .heavy)
                    .foregroundStyle(Theme.green)
                    .frame(width: 44, height: 44)
                    .background(Theme.mint, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var wordInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(card.targetWord)
                    .manrope(15, .bold).foregroundStyle(Theme.ink)
                if let p = card.pronunciation, !p.isEmpty {
                    Text(p).manrope(11.5, .medium).foregroundStyle(Theme.muted)
                }
            }
            if !card.nativeTranslation.isEmpty {
                Text(card.nativeTranslation)
                    .manrope(12.5, .medium).foregroundStyle(Theme.muted)
            }
        }
    }

    private var dueInfo: some View {
        Group {
            if card.isDueToday {
                Text("DUE")
                    .manrope(9.5, .heavy)
                    .foregroundStyle(Theme.green)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.mintChip, in: Capsule())
            } else {
                Text(card.srsState.nextReview, style: .relative)
                    .manrope(11.5, .semibold)
                    .foregroundStyle(Theme.faint)
            }
        }
    }
}
