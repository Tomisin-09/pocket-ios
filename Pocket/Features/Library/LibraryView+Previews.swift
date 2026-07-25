import SwiftData
import SwiftUI

/// Varied songs for the library preview so each Group-by key has buckets to show.
private struct PreviewSeed {
    let title: String
    let artist: String
    let genre: String
    /// Target derived mastery — applied to the sample's loops so `Song.mastery` rolls up to
    /// it. `nil` clears the loops so the song lands in the "Unrated" bucket (ADR 0036).
    let mastery: Int?
    let collections: [String]

    static let library: [PreviewSeed] = [
        .init(title: "Blue Hour", artist: "The Allmans", genre: "Blues",
              mastery: 3, collections: ["blues"]),
        .init(title: "Red Moon", artist: "Zydeco Trio", genre: "Folk",
              mastery: 1, collections: ["blues", "needs-work"]),
        .init(title: "Apex", artist: "Arc", genre: "Rock",
              mastery: 5, collections: ["rock"]),
        .init(title: "Little Wing", artist: "Jimi Hendrix", genre: "Rock",
              mastery: 2, collections: []),
        .init(title: "3 Strikes", artist: "", genre: "",
              mastery: nil, collections: ["needs-work"])
    ]
}

#Preview("Library — with songs") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    // A few varied songs so the Group-by control has something to bucket.
    for seed in PreviewSeed.library {
        let song = Song.sample()
        song.title = seed.title
        song.artist = seed.artist
        song.genre = seed.genre
        if let mastery = seed.mastery {
            song.loops.forEach { $0.mastery = mastery }
        } else {
            song.loops = []   // no loops → derived mastery is nil ("Unrated")
        }
        song.collections = seed.collections
        song.dateAdded = .now
        container.mainContext.insert(song)
    }
    return NavigationStack { LibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

// Regular-width variant (ADR 0105): forces the regular horizontal size class in a wide frame
// to inspect how the list caps to a centred readable column at iPad / landscape width without
// an iPad build. Dormant on the iPhone-only v1 build.
#Preview("Library — regular width (iPad groundwork)") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    for seed in PreviewSeed.library {
        let song = Song.sample()
        song.title = seed.title
        song.artist = seed.artist
        song.genre = seed.genre
        if let mastery = seed.mastery { song.loops.forEach { $0.mastery = mastery } } else { song.loops = [] }
        song.collections = seed.collections
        song.dateAdded = .now
        container.mainContext.insert(song)
    }
    return NavigationStack { LibraryView() }
        .modelContainer(container)
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 900)
}

#Preview("Library — empty") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return NavigationStack { LibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("Song edit sheet") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let song = Song.sample()
    container.mainContext.insert(song)
    return SongEditSheet(song: song).modelContainer(container)
}
