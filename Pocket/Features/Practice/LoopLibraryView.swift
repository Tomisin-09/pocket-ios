import SwiftData
import SwiftUI

/// The **Loops** library inside Practice (ADR 0046 Phase B): the focused list of song loops you've
/// **measured** (a command tempo set), pushed from the Practice hub. A measured loop is a trainable
/// unit — tapping a row opens its `LoopRunView` to train the same warm-up → dwell → reach → back-off
/// staircase as an exercise, against the loop's time-stretched audio, and a per-row **Ear** button
/// opens the same loop in **ear training** (`EarTrainingView`, ADR 0104) so both practice modes are
/// reachable here, not just the ramp.
///
/// No creation or deletion here: a loop belongs to its **song**, made and removed on the waveform
/// screen. This library is a read-through onto the loops worth training. The `commandTempo != nil`
/// gate is an **in-memory** filter, not a SwiftData optional `#Predicate` (which starves the main
/// thread — see `PracticeRunUITests`). Sort key + direction and the search query narrow the list in
/// memory too (ADR 0056), reusing the pure `PracticeLibrarySort`.
struct LoopLibraryView: View {
    @Query private var allLoops: [Loop]
    /// Sort key + direction, persisted across launches (ADR 0056).
    @AppStorage("loopLibrarySort") private var sortKey: LoopSortKey = .song
    @AppStorage("loopLibrarySortAscending") private var sortAscending = true
    @State private var searchText = ""
    /// Whether the list is narrowed to favourited passages (ADR 0119) — a session toggle, not persisted.
    @State private var favoritesOnly = false
    /// The loop + mode a row launched, driving a programmatic push (a plain `NavigationLink` can't carry
    /// the two side-by-side buttons without the row swallowing the Ear tap).
    @State private var launch: LoopLaunch?

    /// A loop opened in one of its two practice modes — the ramp `trainer` or `ear` training (ADR 0104).
    private enum LoopLaunch: Identifiable, Hashable {
        case trainer(Loop)
        case ear(Loop)

        var id: String {
            switch self {
            case .trainer(let loop): return "trainer-\(loop.uid)"
            case .ear(let loop): return "ear-\(loop.uid)"
            }
        }
    }

    /// The measured loops (a command set) narrowed by search and ordered by the current sort.
    private var visibleLoops: [Loop] {
        let measured = allLoops
            .filter { $0.commandTempo != nil }
            .filter { !favoritesOnly || $0.isFavorite }
            .filter { PracticeLibrarySort.loopMatches(fields(for: $0), query: searchText) }
        return PracticeLibrarySort.sortedLoops(measured, by: sortKey,
                                               ascending: sortAscending, fields: fields(for:))
    }

    /// Are there measured loops at all, before the search narrows them? Distinguishes the
    /// "none yet" empty state from the "no search matches" one.
    private var hasMeasuredLoops: Bool { allLoops.contains { $0.commandTempo != nil } }

    private func fields(for loop: Loop) -> LoopSortFields {
        LoopSortFields(name: loop.name, songTitle: loop.song?.title ?? "",
                       command: loop.command, mastery: loop.mastery)
    }

    var body: some View {
        List {
            if !hasMeasuredLoops {
                Text("No measured loops yet. Open a song, set a loop's command tempo on the "
                     + "waveform, and it'll show up here to train.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else if visibleLoops.isEmpty {
                Text(favoritesOnly
                     ? "No favourite loops yet. Swipe a loop and tap Favourite to pin it."
                     : "No loops match “\(searchText)”.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(visibleLoops) { loop in
                    loopRow(loop)
                        .listRowBackground(PocketColor.background)
                        .swipeActions(edge: .leading) { favoriteButton(for: loop) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Loops")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Loops and songs")
        .toolbar {
            if hasMeasuredLoops {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        favoritesOnly.toggle()
                        haptic(.light)
                    } label: {
                        Image(systemName: favoritesOnly ? "star.fill" : "star")
                    }
                    .tint(PocketColor.practice)
                    .accessibilityLabel(favoritesOnly ? "Showing favourites only" : "Show favourites only")
                }
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
            }
        }
        .navigationDestination(item: $launch) { launch in
            switch launch {
            case .trainer(let loop):
                LoopRunView(loop: loop)
            case .ear(let loop):
                EarTrainingView(loop: loop)
                    .navigationTitle("Train your ear")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    /// A loop row: the unit summary (tap → ramp trainer) beside an **Ear** button (tap → ear training).
    /// Two sibling buttons rather than a nested pair, each with a non-default style, so the List routes
    /// each tap to its own target instead of firing the whole row.
    @ViewBuilder
    private func loopRow(_ loop: Loop) -> some View {
        HStack(spacing: 12) {
            Button {
                launch = .trainer(loop)
            } label: {
                HStack {
                    PracticeUnitRow(title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                                    context: loop.song?.title,
                                    progress: "Command \(LoopCommandRamp.percent(loop.command))% → "
                                        + "\(LoopCommandRamp.percent(loop.targetSpeed))%",
                                    isFavorite: loop.isFavorite)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                launch = .ear(loop)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "ear")
                        .font(.futura(.body))
                    Text("Ear")
                        .font(.futura(.caption2))
                }
                .foregroundStyle(PocketColor.practice)
                .padding(.leading, 4)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Train your ear with \(loop.name.isEmpty ? "untitled loop" : loop.name)")
        }
    }

    /// The leading-swipe favourite toggle for a loop (ADR 0119) — the pin that surfaces this passage
    /// in the Home favourites rail's cross-song "my key passages" view.
    private func favoriteButton(for loop: Loop) -> some View {
        Button {
            loop.isFavorite.toggle()
            haptic(.light)
        } label: {
            Label(loop.isFavorite ? "Unfavourite" : "Favourite",
                  systemImage: loop.isFavorite ? "star.slash" : "star")
        }
        .tint(PocketColor.practice)
    }

    /// The sort control — a menu whose label spells out the active key with a direction arrow, and
    /// whose contents pick the key and flip ascending/descending (ADR 0056, mirroring the library).
    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortKey) {
                ForEach(LoopSortKey.allCases) { key in
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
                Text(sortKey.label)
            }
            .tint(PocketColor.practice)
        }
        .accessibilityLabel("Sort by \(sortKey.label), \(sortAscending ? "ascending" : "descending")")
    }
}

#Preview("Loops — empty") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return NavigationStack { LoopLibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
