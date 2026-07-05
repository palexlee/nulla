import SwiftUI
import SwiftData

struct LanguageSwitcherSheet: View {
    @Query private var languages: [Language]
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.surface2)
                    .frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 22)

                Text("Languages")
                    .manrope(22, .heavy).foregroundStyle(Theme.ink)
                    .padding(.bottom, 18)

                ForEach(languages) { language in
                    languageRow(language)
                        .padding(.bottom, 10)
                }

                HStack(spacing: 14) {
                    Text("+")
                        .manrope(20, .heavy).foregroundStyle(Theme.green)
                    Text("Add a language")
                        .manrope(14, .bold).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 15).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.rTile)
                        .stroke(Theme.surface2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )

                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func languageRow(_ language: Language) -> some View {
        let isActive = language.code == selectedLanguageCode
        let dueLabel = language.dueCount > 0 ? "\(language.dueCount) due" : "all caught up"
        return Button {
            selectedLanguageCode = language.code
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(language.flag).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .manrope(16, .heavy).foregroundStyle(Theme.ink)
                    Text("\(language.level.label) · \(dueLabel)")
                        .manrope(12, .semibold).foregroundStyle(Theme.muted)
                }
                Spacer()
                if isActive {
                    ZStack {
                        Circle().fill(Theme.green).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.onGreen)
                    }
                }
            }
            .padding(.horizontal, 15).padding(.vertical, 14)
            .background(isActive ? Theme.mint : Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rTile))
        }
        .buttonStyle(.plain)
    }
}
