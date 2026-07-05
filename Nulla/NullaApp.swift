import SwiftUI
import SwiftData

@main
struct NullaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Language.self, FlashCard.self])
    }
}
