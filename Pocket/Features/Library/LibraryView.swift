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
    /// Sort direction within the current grouping — `true` is the natural order (A→Z,
    /// newest-first); `false` flips the whole list. Persisted across launches.
    @AppStorage("librarySortAscending") private var sortAscending = true
    /// Title/artist search query (ADR 0035).
    @State private var searchText = ""
    /// Presents the standalone metronome. **Temporary** Library entry point (ADR 0043):
    /// the tool belongs with warm-up routines on a future home screen (ADR 0026), but a
    /// toolbar button unblocks it until app-wide navigation exists. Remove when the home
    /// screen lands.
    @State private var showingMetronome = false

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    LibraryEmptyState(onImport: { importing = true }, onTryDemo: addDemo)
                } else {
                    libraryContent
                        .searchable(text: $searchText, prompt: "Songs and artists")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !songs.isEmpty { sortMenu }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !availableCollections.isEmpty { filterMenu }
                    // Temporary metronome entry point (ADR 0043) — moves to the home screen later.
                    Button { showingMetronome = true } label: { Image(systemName: "metronome") }
                        .tint(PocketColor.metronome)
                        .accessibilityLabel("Metronome")
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
            .fullScreenCover(isPresented: $showingMetronome) {
                MetronomeView()
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

    /// Songs narrowed by the active collection filter (AND) and the search query. Order
    /// is the `@Query` title sort, preserved by `filter`.
    private var filteredSongs: [Song] {
        songs.filter {
            Labels.matches($0.collections, allOf: Array(selectedCollections))
                && LibrarySectioning.matchesSearch(fields(for: $0), query: searchText)
        }
    }

    /// The grouping/search projection of a song (ADR 0035).
    private func fields(for song: Song) -> SongGroupFields {
        SongGroupFields(title: song.title, artist: song.artist, album: song.album,
                        genre: song.genre, mastery: song.mastery,
                        dateAdded: song.dateAdded)
    }

    /// The filtered songs grouped into ordered sections by the current key and direction (ADR 0035).
    private var sections: [LibrarySection<Song>] {
        LibrarySectioning.sections(filteredSongs, by: grouping, ascending: sortAscending,
                                   fields: fields(for:))
    }

    /// The list, or the right empty state when the filter/search excludes everything.
    @ViewBuilder
    private var libraryContent: some View {
        if filteredSongs.isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                NoMatchesState { selectedCollections.removeAll() }
            }
        } else {
            groupedList
        }
    }

    /// The sort control — a menu whose **label spells out the current category** (so it's
    /// always clear what the list is sorted by) with a direction arrow, and whose contents
    /// pick the category and flip ascending/descending (ADR 0035).
    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $grouping) {
                ForEach(SongGrouping.allCases) { key in
                    Text(key.label).tag(key)
                }
            }
            Picker("Order", selection: $sortAscending) {
                Label("Ascending", systemImage: "arrow.up").tag(true)
                Label("Descending", systemImage: "arrow.down").tag(false)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                Text(grouping.label)
            }
            .tint(PocketColor.active)
        }
        .accessibilityLabel("Sort by \(grouping.label), \(sortAscending ? "ascending" : "descending")")
    }

    /// Collection filter, relocated from the old header chip bar into a toolbar menu
    /// (ADR 0033 / 0035): toggle collections (intersection/AND), with a clear option. The
    /// icon fills when a filter is active. Shown only when some song carries a collection.
    private var filterMenu: some View {
        Menu {
            if !selectedCollections.isEmpty {
                Button { selectedCollections.removeAll() } label: {
                    Label("Clear filter", systemImage: "xmark.circle")
                }
                Divider()
            }
            ForEach(availableCollections, id: \.self) { collection in
                Button { toggleCollection(collection) } label: {
                    if selectedCollections.contains(collection) {
                        Label(collection, systemImage: "checkmark")
                    } else {
                        Text(collection)
                    }
                }
            }
        } label: {
            Image(systemName: selectedCollections.isEmpty
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .tint(PocketColor.active)
        }
        .accessibilityLabel(selectedCollections.isEmpty
                            ? "Filter by collection"
                            : "Filtering by \(selectedCollections.count) collection(s)")
    }

    private func toggleCollection(_ collection: String) {
        if selectedCollections.contains(collection) {
            selectedCollections.remove(collection)
        } else {
            selectedCollections.insert(collection)
        }
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
                        // Hold a card for its actions (Edit opens the metadata sheet); swipe
                        // still offers a quick Delete. Tap opens the song for practice.
                        .contextMenu {
                            Button { editingSong = song } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) { context.delete(song) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { context.delete(song) } label: {
                                Label("Delete", systemImage: "trash")
                            }
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
