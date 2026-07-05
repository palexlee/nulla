//
//  ReviewView.swift
//
//  "Soft" restyle + 3D flip + the personality wrong-answer reaction and
//  session-complete screen. Uses the existing SRSService / ReviewRating.
//

import SwiftUI
import SwiftData
import UIKit

struct ReviewView: View {
    let language: Language
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("personality") private var personalityRaw = Personality.full.rawValue

    @State private var queue: [FlashCard] = []
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var completedCount = 0
    @State private var reaction: String? = nil     // wrong-answer line
    @State private var showSummary = false

    private var personality: Personality { Personality(rawValue: personalityRaw) ?? .full }
    private var copy: Copy { Copy(personality: personality, reviewed: completedCount) }

    var currentCard: FlashCard? {
        currentIndex < queue.count ? queue[currentIndex] : nil
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if showSummary {
                summaryView
            } else if let card = currentCard {
                reviewView(card)
            } else {
                ContentUnavailableView("Nothing due", systemImage: "checkmark.circle")
            }
        }
        .onAppear { queue = language.dueCards.shuffled() }
    }

    // MARK: Review

    private func reviewView(_ card: FlashCard) -> some View {
        VStack(spacing: 16) {
            // progress
            HStack(spacing: 14) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").manrope(18, .bold).foregroundStyle(Theme.muted)
                }
                ProgressView(value: Double(currentIndex), total: Double(max(queue.count, 1)))
                    .tint(Theme.green)
                Text("\(currentIndex + 1)/\(queue.count)")
                    .manrope(12, .bold).foregroundStyle(Theme.muted)
            }

            // flip card
            CardFace(card: card, isFlipped: isFlipped)
                .onTapGesture {
                    if !isFlipped { withAnimation(.spring(duration: 0.55)) { isFlipped = true } }
                }

            if let reaction {
                reactionBlock(reaction, card: card)
            } else if isFlipped {
                ratingButtons(card)
            } else {
                Color.clear.frame(height: 132)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func ratingButtons(_ card: FlashCard) -> some View {
        HStack(spacing: 8) {
            ForEach(ReviewRating.allCases, id: \.rawValue) { rating in
                Button { rate(card, rating) } label: {
                    VStack(spacing: 3) {
                        Text(rating.label).manrope(13, .bold)
                        Text(SRSService.nextIntervalDescription(for: card.srsState, rating: rating))
                            .manrope(10, .semibold).opacity(0.7)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .foregroundStyle(fg(rating))
                    .background(bg(rating), in: RoundedRectangle(cornerRadius: Theme.rPill))
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func reactionBlock(_ text: String, card: FlashCard) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("🙃").font(.system(size: 17))
                Text(text).manrope(13.5, .semibold).foregroundStyle(Theme.onCoral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(Theme.coral, in: RoundedRectangle(cornerRadius: Theme.rPill))

            Button { advance(requeue: card) } label: {
                Text("Keep going").manrope(14, .bold).foregroundStyle(Theme.paper)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.rPill))
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Summary

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }.manrope(13, .bold).foregroundStyle(Theme.muted)
            }
            Spacer()
            ZStack {
                Circle().fill(Theme.mint).frame(width: 64, height: 64)
                Image(systemName: "checkmark").manrope(24, .bold).foregroundStyle(Theme.green)
            }
            .padding(.bottom, 26)
            Text("SESSION COMPLETE").manrope(12, .bold).tracking(0.5).foregroundStyle(Theme.green)
                .padding(.bottom, 12)
            Text(copy.sessionTitle).manrope(26, .heavy).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true).padding(.bottom, 14)
            Text(copy.sessionSub).manrope(14, .medium).foregroundStyle(Theme.faint)
            Spacer()
            HStack(spacing: 10) {
                summaryTile("\(completedCount)", "reviewed", Theme.surface, Theme.ink)
                summaryTile("\(language.streak)", "day streak", Theme.butter, Theme.onButter)
            }
            .padding(.bottom, 10)
            Button { dismiss() } label: {
                Text("Done for today").manrope(14, .bold).foregroundStyle(Theme.onGreen)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Theme.green, in: RoundedRectangle(cornerRadius: Theme.rPill))
            }
        }
        .padding(20)
    }

    private func summaryTile(_ v: String, _ l: String, _ bg: Color, _ fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).manrope(20, .heavy).foregroundStyle(fg)
            Text(l).manrope(11, .semibold).foregroundStyle(fg.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(15)
        .background(bg, in: RoundedRectangle(cornerRadius: Theme.rPill))
    }

    // MARK: Logic

    private func rate(_ card: FlashCard, _ rating: ReviewRating) {
        if rating == .again {
            withAnimation { reaction = copy.wrong }
            return
        }
        var state = card.srsState
        SRSService.schedule(state: &state, rating: rating)
        card.srsState = state
        completedCount += 1
        advance(requeue: nil)
    }

    private func advance(requeue card: FlashCard?) {
        if let card {                     // "Again": requeue this card to the end
            var state = card.srsState
            SRSService.schedule(state: &state, rating: .again)
            card.srsState = state
            completedCount += 1
            queue.append(card)
        }
        withAnimation {
            reaction = nil
            isFlipped = false
            currentIndex += 1
            if currentIndex >= queue.count {
                language.registerStudySession()
                showSummary = true
            }
        }
    }

    private func bg(_ r: ReviewRating) -> Color {
        switch r { case .again: Theme.coral; case .hard: Theme.butter; case .good: Theme.green; case .easy: Theme.lavender }
    }
    private func fg(_ r: ReviewRating) -> Color {
        switch r { case .again: Theme.onCoral; case .hard: Theme.onButter; case .good: Theme.onGreen; case .easy: Theme.onLav }
    }
}

// MARK: - Flip card

private struct CardFace: View {
    let card: FlashCard
    let isFlipped: Bool

    var body: some View {
        ZStack {
            front.opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (0, 1, 0))
            back.opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (0, 1, 0))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 380)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: Theme.green.opacity(0.09), radius: 20, y: 16)
    }

    private var front: some View {
        VStack(spacing: 12) {
            Text(card.targetWord).manrope(60, .heavy).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            if let p = card.pronunciation {
                Text(p).manrope(18, .semibold).foregroundStyle(Theme.muted)
            }
            Text(card.source == .camera ? "FROM CAMERA" : "ADDED MANUALLY")
                .manrope(10.5, .bold).foregroundStyle(Theme.green)
                .padding(.horizontal, 11).padding(.vertical, 4)
                .background(Theme.mint, in: Capsule())
                .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            Text("Tap to reveal").manrope(12, .semibold).foregroundStyle(Theme.faint).padding(.bottom, 22)
        }
        .padding(28)
    }

    private var back: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let data = card.sourceThumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 120, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(card.targetWord).manrope(28, .heavy)
                if let p = card.pronunciation {
                    Text(p).manrope(14, .semibold).foregroundStyle(Theme.muted)
                }
            }
            Divider().padding(.vertical, 18)
            Text(card.nativeTranslation).manrope(26, .heavy).foregroundStyle(Theme.ink)
            if let s = card.exampleSentence {
                Text(s).manrope(15, .medium).foregroundStyle(Theme.faint).padding(.top, 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(30)
    }
}
