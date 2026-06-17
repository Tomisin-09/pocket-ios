import SwiftData
import SwiftUI

@main
struct PocketApp: App {
    var body: some Scene {
        WindowGroup {
            // Temporary: launch straight into the practice screen on the first
            // song. A real library + import lands in the next slice (Phase 3 nav).
            PracticeRoot()
        }
        .modelContainer(for: [Song.self, Loop.self, Marker.self])
    }
}

/// Loads the song to practice from SwiftData, seeding the generated demo sample on
/// first launch (empty store) so there's always something to open.
private struct PracticeRoot: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.title) private var songs: [Song]

    var body: some View {
        if let song = songs.first {
            WaveformPracticeView(song: song, context: context)
        } else {
            PocketColor.background.ignoresSafeArea()
                .task { context.insert(Song.sample()) }
        }
    }
}
