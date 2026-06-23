import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The app root: the song library (ADR 0011 Slice 2). A simple list of songs to
/// open for practice, a `+` to import an audio file, and an empty state offering
/// import or the bundled demo. Replaces the temporary launch-into-first-song.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.title) private var songs: [Song]
    @State private var importing = false
    @State private var importError: String?
    @State private var editingSong: Song?
    /// Canonical collection names the library is filtered by; empty ⇒ no filter
    /// (intersection/AND semantics — a song matches if it has all selected). ADR 0033.
    @State private var selectedCollections: Set<String> = []
    /// How the list is grouped/ordered (ADR 0035) — persisted across launches.
    @AppStorage("libraryGrouping") private var grouping: SongGrouping = .title

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    LibraryEmptyState(onImport: { importing = true }, onTryDemo: addDemo)
                } else {
                    VStack(spacing: 0) {
                        if !availableCollections.isEmpty {
                            CollectionFilterBar(available: availableCollections,
                                                selected: $selectedCollections)
                        }
                        if filteredSongs.isEmpty {
                            NoMatchesState { selectedCollections.removeAll() }
                        } else {
                            groupedList
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !songs.isEmpty { groupByMenu }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "plus") }
                        .tint(PocketColor.active)
                        .accessibilityLabel("Import a song")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], onCompletion: handleImport)
            .alert("Couldn’t import", isPresented: importErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .sheet(item: $editingSong) { song in
                SongEditSheet(song: song)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Distinct collection names across the library, canonicalised and sorted — the
    /// filter chips (ADR 0033).
    private var availableCollections: [String] {
        Labels.normalized(songs.flatMap(\.collections))
            .sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Songs narrowed by the active collection filter (intersection/AND). Order is the
    /// `@Query` title sort, preserved by `filter`.
    private var filteredSongs: [Song] {
        songs.filter { Labels.matches($0.collections, allOf: Array(selectedCollections)) }
    }

    /// The filtered songs grouped into ordered sections by the current key (ADR 0035).
    private var sections: [LibrarySection<Song>] {
        LibrarySectioning.sections(filteredSongs, by: grouping) { song in
            SongGroupFields(title: song.title, artist: song.artist, album: song.album,
                            genre: song.genre, proficiency: song.proficiency,
                            dateAdded: song.dateAdded)
        }
    }

    private var groupByMenu: some View {
        Menu {
            Picker("Group by", selection: $grouping) {
                ForEach(SongGrouping.allCases) { key in
                    Text(key.label).tag(key)
                }
            }
        } label: {
            Label("Group by", systemImage: "arrow.up.arrow.down")
                .tint(PocketColor.active)
        }
        .accessibilityLabel("Group by \(grouping.label)")
    }

    private var groupedList: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.items) { song in
                        NavigationLink {
                            WaveformPracticeView(song: song, context: context)
                        } label: {
                            SongCard(song: song)
                        }
                        .listRowBackground(PocketColor.background)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { context.delete(song) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { editingSong = song } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(PocketColor.active)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try SongImporter.importSong(from: url, into: context)
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func addDemo() { context.insert(Song.sample()) }
}

/// Horizontal row of collection filter chips above the song list (ADR 0033). A
/// leading **All** chip clears the filter; tapping a collection toggles it in/out of
/// the intersection. Hidden entirely when no song carries a collection.
private struct CollectionFilterBar: View {
    let available: [String]
    @Binding var selected: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selected.isEmpty) { selected.removeAll() }
                ForEach(available, id: \.self) { collection in
                    FilterChip(label: collection, isSelected: selected.contains(collection)) {
                        toggle(collection)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(PocketColor.background)
    }

    private func toggle(_ collection: String) {
        if selected.contains(collection) {
            selected.remove(collection)
        } else {
            selected.insert(collection)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.pocketMono(.caption))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(isSelected ? PocketColor.active : Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }
}

/// Shown when the active collection filter excludes every song — a clear message and
/// a one-tap way back to the full library (ADR 0033).
private struct NoMatchesState: View {
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundStyle(PocketColor.textSecondary)
            Text("No songs in this collection")
                .font(.headline)
                .foregroundStyle(PocketColor.textPrimary)
            Button("Clear filter", action: onClear)
                .font(.subheadline)
                .foregroundStyle(PocketColor.active)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// First-run / empty library: offer import or the bundled demo — ADR 0011 retires
/// the auto-seed in favour of this explicit choice.
private struct LibraryEmptyState: View {
    let onImport: () -> Void
    let onTryDemo: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44))
                .foregroundStyle(PocketColor.textSecondary)
            Text("No songs yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text("Import an audio file to practice with its real waveform.")
                .font(.footnote)
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button(action: onImport) {
                    Label("Import a song", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(PocketColor.active.opacity(0.18), in: .rect(cornerRadius: 12))
                .foregroundStyle(PocketColor.active)

                Button("Try the demo", action: onTryDemo)
                    .font(.subheadline)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(.top, 4)
        }
        .padding(40)
    }
}

/// Varied songs for the library preview so each Group-by key has buckets to show.
private struct PreviewSeed {
    let title: String
    let artist: String
    let genre: String
    let proficiency: Int
    let collections: [String]

    static let library: [PreviewSeed] = [
        .init(title: "Blue Hour", artist: "The Allmans", genre: "Blues",
              proficiency: 3, collections: ["blues"]),
        .init(title: "Red Moon", artist: "Zydeco Trio", genre: "Folk",
              proficiency: 1, collections: ["blues", "needs-work"]),
        .init(title: "Apex", artist: "Arc", genre: "Rock",
              proficiency: 5, collections: ["rock"]),
        .init(title: "Little Wing", artist: "Jimi Hendrix", genre: "Rock",
              proficiency: 2, collections: []),
        .init(title: "3 Strikes", artist: "", genre: "",
              proficiency: 0, collections: ["needs-work"])
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
        song.proficiency = seed.proficiency
        song.collections = seed.collections
        song.dateAdded = .now
        container.mainContext.insert(song)
    }
    return LibraryView().modelContainer(container)
}

#Preview("Library — empty") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return LibraryView().modelContainer(container)
}

#Preview("Song edit sheet") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let song = Song.sample()
    container.mainContext.insert(song)
    return SongEditSheet(song: song).modelContainer(container)
}
