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
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            Group {
                if let lang = selectedLanguage {
                    DeckView(language: lang)
                } else {
                    ProgressView()
                }
            }
            .tabItem { Label("Deck", systemImage: "rectangle.stack.fill") }
            .tag(1)
        }
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
}
