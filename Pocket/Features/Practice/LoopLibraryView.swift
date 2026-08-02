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
    /// Whether the list is **widened** past the trainer gate to every loop (ADR 0138 G4) — the way to
    /// reach an unmeasured loop and train your ear with it. A session toggle like Favourites: the
    /// default listing is the measured one, and this is a deliberate look elsewhere, not a preference.
    @State private var showAllLoops = false
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

    /// The loops in scope before search and favourites narrow them (ADR 0138 G4). The default listing
    /// keeps the **trainer** gate, because this list *is* the practice library and admitting every
    /// scratch region a player ever dragged would drown it; `showAllLoops` is the deliberate way past
    /// it, not a new default.
    private var loopsInScope: [Loop] {
        showAllLoops ? allLoops : allLoops.filter { LoopModeAccess.allows(.trainer, $0) }
    }

    /// The in-scope loops narrowed by search and ordered by the current sort.
    private var visibleLoops: [Loop] {
        let narrowed = loopsInScope
            .filter { !favoritesOnly || $0.isFavorite }
            .filter { PracticeLibrarySort.loopMatches(fields(for: $0), query: searchText) }
        return PracticeLibrarySort.sortedLoops(narrowed, by: sortKey,
                                               ascending: sortAscending, fields: fields(for:))
    }

    /// Are there measured loops at all, before search narrows them? Distinguishes the "none yet"
    /// empty state from the "no search matches" one.
    private var hasMeasuredLoops: Bool { allLoops.contains { LoopModeAccess.allows(.trainer, $0) } }

    /// Whether the options menu is offered. Deliberately **any** loop, not just a measured one: the
    /// "Show all loops" filter lives in that menu, so gating the menu on the very thing the filter
    /// exists to bypass would make an unmeasured-only library unreachable by design.
    private var hasAnyLoops: Bool { !allLoops.isEmpty }

    /// The "nothing to train" copy. It used to name setting a command tempo as though that were the
    /// only way in; with ear training no longer behind that gate (ADR 0138), it has to admit the
    /// other route — but only when there are unmeasured loops for the filter to reveal, so a genuinely
    /// empty library isn't offered a filter that would show it the same nothing.
    private var emptyStateMessage: String {
        hasAnyLoops
            ? "No measured loops yet. Set a loop's command tempo on the waveform and it'll show up "
              + "here to train — or show all loops from the options menu to train your ear with any "
              + "of them, no tempo needed."
            : "No loops yet. Open a song, draw a loop on the waveform, and it'll show up here."
    }

    private func fields(for loop: Loop) -> LoopSortFields {
        LoopSortFields(name: loop.name, songTitle: loop.song?.title ?? "",
                       command: loop.command, mastery: loop.mastery)
    }

    var body: some View {
        List {
            if !hasMeasuredLoops && !showAllLoops {
                Text(emptyStateMessage)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else if visibleLoops.isEmpty {
                Text(favoritesOnly
                     ? "No favourite loops yet. Swipe or hold a loop and tap Favourite to pin it."
                     : searchText.isEmpty
                       ? "No loops yet. Open a song and draw one on the waveform."
                       : "No loops match “\(searchText)”.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(visibleLoops) { loop in
                    loopRow(loop)
                        .listRowBackground(PocketColor.background)
                        .pocketRowActions(displayName(loop),
                                          tint: PocketColor.practice,
                                          menu: menuItems(for: loop),
                                          favorite: favorite(for: loop))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Loops")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Loops and songs")
        // One fixed-width trailing control for sort + favourites, matching the exercise and routine
        // libraries so the inline title centres against the back button alone (`LibraryOptionsMenu`).
        .toolbar {
            if hasAnyLoops {
                ToolbarItem(placement: .topBarTrailing) {
                    LibraryOptionsMenu(favoritesOnly: $favoritesOnly,
                                       widenFilter: $showAllLoops,
                                       widenFilterLabel: "Show all loops",
                                       sortControls: {
                        LibrarySortPickers(sortKey: $sortKey, ascending: $sortAscending)
                    })
                }
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

    /// A loop row, offering **exactly the modes that loop qualifies for** (ADR 0138 G4). Two sibling
    /// buttons rather than a nested pair, each with a non-default style, so the List routes each tap
    /// to its own target instead of firing the whole row.
    ///
    /// With "Show all loops" on, an unmeasured loop appears with **no trainer target** — its summary
    /// is inert text stating what it's missing, and only the Ear button is live. Offering a tap that
    /// opens a ramp with nothing to anchor it would be the same category of mistake this ADR fixes,
    /// one screen further along.
    @ViewBuilder
    private func loopRow(_ loop: Loop) -> some View {
        let canTrain = LoopModeAccess.allows(.trainer, loop)
        HStack(spacing: 12) {
            if canTrain {
                Button {
                    launch = .trainer(loop)
                } label: {
                    summary(loop).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                summary(loop)
            }

            if LoopModeAccess.allows(.ear, loop) {
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
                .accessibilityLabel("Train your ear with \(displayName(loop))")
            }
        }
    }

    /// The row's unit summary. An unmeasured loop has no command range to state, so it says what it
    /// needs instead of rendering "Command 0% → 0%", which would read as a measurement.
    private func summary(_ loop: Loop) -> some View {
        HStack {
            PracticeUnitRow(title: displayName(loop),
                            context: loop.song?.title,
                            progress: LoopModeAccess.allows(.trainer, loop)
                                ? "Command \(LoopCommandRamp.percent(loop.command))% → "
                                  + "\(LoopCommandRamp.percent(loop.targetSpeed))%"
                                : "No command tempo yet — ear training only",
                            isFavorite: loop.isFavorite)
            Spacer(minLength: 0)
        }
    }

    private func displayName(_ loop: Loop) -> String {
        loop.name.isEmpty ? "Untitled loop" : loop.name
    }

    /// A loop's long-press actions (Slice 3): its two practice modes, so both are reachable from the
    /// menu as well as from the row's two tap targets.
    ///
    /// **No Delete here, deliberately** — a loop belongs to its song and is removed on the waveform
    /// where it was drawn (this library is a read-through, see the type doc). The shared modifier
    /// takes an optional delete precisely so a list can decline it rather than inventing a second
    /// owner for the same object.
    /// Built from `LoopModeAccess.modes(for:)` rather than listed by hand, so the menu and the row's
    /// buttons can't disagree about what a loop can do — and so a mode added later (ADR 0135's
    /// Improvise) appears in both the moment its precondition is stated.
    private func menuItems(for loop: Loop) -> [PocketRowMenuItem] {
        LoopModeAccess.modes(for: loop).map { mode in
            switch mode {
            case .trainer:
                PocketRowMenuItem("Practice", systemImage: "play.circle") { launch = .trainer(loop) }
            case .ear:
                PocketRowMenuItem("Train your ear", systemImage: "ear") { launch = .ear(loop) }
            }
        }
    }

    /// The favourite pin (ADR 0119) — what surfaces this passage in the cross-song "my key
    /// passages" view.
    private func favorite(for loop: Loop) -> PocketRowFavorite {
        PocketRowFavorite(isFavorite: loop.isFavorite) { loop.isFavorite.toggle() }
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
