import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The song library (ADR 0011 Slice 2): a list of songs to open for practice, a `+` to
/// import an audio file, and an empty state offering import or the bundled demo. Pushed from
/// the home hub's "See all" (ADR 0044) — it relies on an ambient `NavigationStack` rather
/// than owning one, so its toolbar and row pushes land in the home's navigation.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    /// Entitlement + the shared paywall (ADR 0112) — the collection-session banner builds a routine,
    /// which is Pro.
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    @Query(sort: \Song.title) private var songs: [Song]
    @State private var importing = false
    @State private var importError: String?
    /// Drives multi-select import: progress overlay + partial-failure summary.
    @State private var importModel = SongImportModel()
    @State private var editingSong: Song?
    @State private var detailsSong: Song?
    /// The collection to build a practice session from (ADR 0118) — set by the filtered-Library
    /// banner, drives the `CollectionSessionSheet` configurator.
    @State private var sessionCollection: String?
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

    var body: some View {
        Group {
            if songs.isEmpty {
                LibraryEmptyState(onImport: { importing = true }, onTryDemo: addDemo)
            } else {
                libraryContent
                    .searchable(text: $searchText, prompt: "Songs and artists")
                    .safeAreaInset(edge: .top, spacing: 0) { collectionSessionBar }
            }
        }
        // Cap the list/empty state to a readable column so it doesn't stretch a single
        // narrow run of rows across the full width at regular width (iPad / iPhone Pro Max
        // landscape). Dormant on the iPhone-only v1 build — a no-op at compact width (ADR 0105).
        // The background stays full-bleed behind the centred column.
        .readableWidth()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !songs.isEmpty { sortMenu }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !availableCollections.isEmpty { filterMenu }
                Button { importing = true } label: { Image(systemName: "plus") }
                    .tint(PocketColor.active)
                    .accessibilityLabel("Import songs")
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio],
                      allowsMultipleSelection: true, onCompletion: handleImport)
        .alert("Couldn’t import", isPresented: importErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .songImportFeedback(importModel)
        // Present by a Bool, not `.sheet(item:)` on the `Song`: a session-new song's
        // `persistentModelID` (its default Identifiable id) flips temporary→permanent on the
        // first autosave, and item-based presentation reads that as an identity change and
        // dismisses the sheet mid-edit — the same defect ADR 0090 fixed for loops/markers.
        // `Song` has no stable `uid` to hang a `StableRef` on, so we key the presentation on a
        // Bool instead (as `SongDetailsSheet`'s nested Edit sheet already does).
        .sheet(isPresented: Binding(get: { editingSong != nil },
                                    set: { if !$0 { editingSong = nil } })) {
            if let song = editingSong {
                SongEditSheet(song: song)
            }
        }
        // Details opens the read-first overview (notes + linked exercises, ADR 0111) — reachable
        // from Library so its link authoring doesn't require the waveform title-hold detour. Same
        // Bool-binding presentation as Edit, for the same ADR-0090 identity-flip reason above.
        .sheet(isPresented: Binding(get: { detailsSong != nil },
                                    set: { if !$0 { detailsSong = nil } })) {
            if let song = detailsSong {
                SongDetailsSheet(song: song)
            }
        }
        // Build-a-session configurator (ADR 0118), reached from the filtered-collection banner.
        // Same Bool-binding presentation as the sheets above (`sessionCollection` is a String, not a
        // stable-id @Model, so a Bool binding is the natural fit).
        .sheet(isPresented: Binding(get: { sessionCollection != nil },
                                    set: { if !$0 { sessionCollection = nil } })) {
            if let collection = sessionCollection {
                CollectionSessionSheet(collection: collection, songs: songs)
            }
        }
    }

    /// A prominent "Build a session from these songs" affordance, pinned above the list **only when
    /// the Library is filtered to a single collection** that has at least one linked exercise or loop
    /// to draw from (ADR 0118). Hidden otherwise — the action has no meaning without a single
    /// collection in focus, and would generate lone play-throughs without linked units.
    @ViewBuilder
    private var collectionSessionBar: some View {
        if selectedCollections.count == 1, let collection = selectedCollections.first,
           CollectionSessionBuilder.canBuild(for: collection, in: songs) {
            Button {
                // A generated collection session is a real `Routine` — authoring, so Pro (ADR 0112).
                guard AccessPolicy.canAuthorRoutine(isPro: isPro) else {
                    return presentPaywall(.routine)
                }
                sessionCollection = collection
            } label: {
                Label("Build a session from “\(collection)”",
                      systemImage: isPro ? "wand.and.stars" : "lock.fill")
                    .font(.futura(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .background(PocketColor.practice.opacity(0.18), in: .rect(cornerRadius: 12))
            .foregroundStyle(PocketColor.practice)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(PocketColor.background)
        }
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
                            Button { detailsSong = song } label: {
                                Label("Details", systemImage: "info.circle")
                            }
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

    /// The document picker returns one or more files; `SongImportModel` imports them
    /// off-main and reports any that couldn't be read. A picker-level failure (rare)
    /// surfaces through the separate `importError` alert.
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await importModel.run(urls: urls, into: context) }
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
                .font(.futura(size: 40))
                .foregroundStyle(PocketColor.textSecondary)
            Text("No songs in this collection")
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Button("Clear filter", action: onClear)
                .font(.futura(.subheadline))
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
                .font(.futura(size: 44))
                .foregroundStyle(PocketColor.textSecondary)
            Text("No songs yet")
                .font(.futura(.title3, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text("Import an audio file to practice with its real waveform.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button(action: onImport) {
                    Label("Import a song", systemImage: "square.and.arrow.down")
                        .font(.futura(.headline))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(PocketColor.active.opacity(0.18), in: .rect(cornerRadius: 12))
                .foregroundStyle(PocketColor.active)

                Button("Try the demo", action: onTryDemo)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(.top, 4)
        }
        .padding(40)
    }
}
