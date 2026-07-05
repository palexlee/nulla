//
//  SettingsView.swift
//
//  The personality dial (Off / Dry / Full) with a live sample line, plus a
//  daily-reminder toggle. Presented from HomeView's avatar button.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("personality") private var personalityRaw = Personality.full.rawValue
    @AppStorage("dailyReminder") private var dailyReminder = true

    private var personality: Personality { Personality(rawValue: personalityRaw) ?? .full }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings").manrope(22, .heavy).foregroundStyle(Theme.ink)
                    .padding(.top, 8).padding(.bottom, 20)

                Text("PERSONALITY").manrope(11, .bold).tracking(0.4).foregroundStyle(Theme.muted)
                Text("How much attitude?").manrope(16, .heavy).foregroundStyle(Theme.ink)
                    .padding(.top, 4).padding(.bottom, 14)

                // Segmented dial
                HStack(spacing: 0) {
                    ForEach(Personality.allCases) { p in
                        let on = p == personality
                        Button { personalityRaw = p.rawValue } label: {
                            Text(p.label).manrope(13, on ? .bold : .semibold)
                                .foregroundStyle(on ? Theme.onGreen : Theme.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(on ? Theme.green : .clear,
                                            in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }
                .padding(4)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))

                // Live sample
                Text(Copy(personality: personality).sample)
                    .manrope(13.5, .medium).italic().foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.top, 14)

                Text("Off = plain, encouraging copy. Full = maximum smart-aleck. Same warmth underneath.")
                    .manrope(11.5, .medium).foregroundStyle(Theme.faint)
                    .padding(.top, 10)

                // Reminder toggle
                Toggle(isOn: $dailyReminder) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily reminder").manrope(15, .bold).foregroundStyle(Theme.ink)
                        Text("Nudge me at 9:00").manrope(12, .medium).foregroundStyle(Theme.muted)
                    }
                }
                .tint(Theme.green)
                .padding(.vertical, 14).padding(.top, 10)
                .overlay(Divider(), alignment: .top)

                Spacer()

                Button { dismiss() } label: {
                    Text("Done").manrope(14, .bold).foregroundStyle(Theme.paper)
                        .frame(maxWidth: .infinity).padding(16)
                        .background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.rPill))
                }
            }
            .padding(24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
