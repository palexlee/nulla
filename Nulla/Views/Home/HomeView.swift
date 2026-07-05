//
//  HomeView.swift
//
//  "Soft" restyle: green due-hero, butter streak card with dots, tinted stat
//  tiles, personality-aware greeting + "nothing due" state, Settings sheet.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var languages: [Language]
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode = ""
    @AppStorage("personality") private var personalityRaw = Personality.full.rawValue

    @State private var showReview = false
    @State private var showSettings = false
    @State private var showLanguagePicker = false

    private var personality: Personality { Personality(rawValue: personalityRaw) ?? .full }
    private var copy: Copy { Copy(personality: personality) }

    private var weekday: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: .now)
    }

    var selectedLanguage: Language? {
        languages.first { $0.code == selectedLanguageCode } ?? languages.first
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let lang = selectedLanguage {
                        Text("\(weekday) · \(lang.displayName)")
                            .manrope(13, .semibold).foregroundStyle(Theme.muted)

                        if lang.dueCount > 0 {
                            Text(copy.greeting)
                                .manrope(23, .heavy).foregroundStyle(Theme.ink)
                                .padding(.bottom, 6)
                            dueHero(lang)
                        } else {
                            Text("Nothing due")
                                .manrope(23, .heavy).foregroundStyle(Theme.ink)
                                .padding(.bottom, 6)
                            caughtUpCard
                        }

                        streakCard(lang)
                        statsRow(lang)
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .fullScreenCover(isPresented: $showReview) {
            if let lang = selectedLanguage { ReviewView(language: lang) }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLanguagePicker) { LanguageSwitcherSheet() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("nulla").manrope(21, .heavy).foregroundStyle(Theme.ink)
            Spacer()
            if let lang = selectedLanguage {
                Button { showLanguagePicker = true } label: {
                    HStack(spacing: 6) {
                        Text(lang.flag)
                        Text(lang.level.label).manrope(12.5, .bold)
                        Image(systemName: "chevron.down").font(.system(size: 9))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 14)).foregroundStyle(Theme.muted)
                    .frame(width: 34, height: 34)
                    .background(Theme.surface2, in: Circle())
            }
        }
    }

    // MARK: Due hero

    private func dueHero(_ lang: Language) -> some View {
        Button { showReview = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(lang.dueCount)").manrope(56, .heavy).foregroundStyle(Theme.onGreen)
                Text("cards due today").manrope(15, .semibold)
                    .foregroundStyle(Theme.onGreen.opacity(0.85)).padding(.top, 5)
                HStack(spacing: 8) {
                    Text("Start review").manrope(13, .bold)
                    Image(systemName: "play.fill").font(.system(size: 11))
                }
                .foregroundStyle(Theme.onGreen)
                .padding(.horizontal, 15).padding(.vertical, 9)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                .padding(.top, 16)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.green, in: RoundedRectangle(cornerRadius: Theme.rHero))
            .shadow(color: Theme.green.opacity(0.22), radius: 18, y: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: Caught up

    private var caughtUpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🫡").font(.system(size: 32))
            Text(copy.caughtUpTitle).manrope(20, .heavy).foregroundStyle(Theme.onLav)
            Text(copy.caughtUpSub).manrope(13.5, .medium).foregroundStyle(Theme.onLav.opacity(0.8))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lavender, in: RoundedRectangle(cornerRadius: Theme.rHero))
    }

    // MARK: Streak

    private func streakCard(_ lang: Language) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(lang.streak)").manrope(22, .heavy).foregroundStyle(Theme.onButter)
                Text("day streak").manrope(11, .semibold).foregroundStyle(Theme.gold)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Circle()
                        .fill(i < min(lang.streak, 7) ? Theme.gold : Theme.goldFaint)
                        .frame(width: 11, height: 11)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 15)
        .background(Theme.butter, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Stats

    private func statsRow(_ lang: Language) -> some View {
        HStack(spacing: 10) {
            statTile(value: "\(lang.cards.count)", label: "words", bg: Theme.lavender, fg: Theme.onLav)
            statTile(value: lang.level.label, label: "level", bg: Theme.mint, fg: Theme.green)
        }
    }

    private func statTile(value: String, label: String, bg: Color, fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).manrope(20, .heavy).foregroundStyle(fg)
            Text(label).manrope(11, .semibold).foregroundStyle(fg.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(bg, in: RoundedRectangle(cornerRadius: Theme.rTile))
    }

    private var emptyState: some View {
        ContentUnavailableView("No languages yet", systemImage: "globe",
                               description: Text("Switch to the Deck tab to get started."))
    }
}
