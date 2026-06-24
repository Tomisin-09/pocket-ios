import SwiftData
import SwiftUI

@main
struct PocketApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(for: [Song.self, Loop.self, Marker.self, JournalEntry.self])
    }
}
