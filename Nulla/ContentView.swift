import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var languages: [Language]
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode = ""
    @State private var selectedTab = 0

    var selectedLanguage: Language? {
        languages.first { $0.code == selectedLanguageCode } ?? languages.first
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if selectedTab == 0 {
                    HomeView()
                } else if let lang = selectedLanguage {
                    DeckView(language: lang)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)

            customTabBar
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            guard languages.isEmpty else { return }
            let defaults: [(code: String, name: String, flag: String, level: CEFRLevel)] = [
                ("zh-Hans", "Chinese", "🇨🇳", .a2),
                ("de", "German", "🇩🇪", .a2),
                ("de-CH", "Swiss German", "🇨🇭", .a0),
            ]
            for lang in defaults {
                context.insert(Language(code: lang.code, displayName: lang.name, flag: lang.flag, level: lang.level))
            }
            selectedLanguageCode = "zh-Hans"
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton("Home", tag: 0)
            tabButton("Deck", tag: 1)
        }
        .padding(.horizontal, 40)
        .padding(.top, 14)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.paper.opacity(0), Theme.paper],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.38)
            )
        )
    }

    private func tabButton(_ title: String, tag: Int) -> some View {
        let active = selectedTab == tag
        return Button { selectedTab = tag } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(active ? Theme.green : Color.clear)
                    .frame(width: 6, height: 6)
                Text(title)
                    .manrope(12, .bold)
                    .foregroundStyle(active ? Theme.green : Theme.faint)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}
