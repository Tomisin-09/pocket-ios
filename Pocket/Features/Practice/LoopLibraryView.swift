import SwiftData
import SwiftUI

/// The **Loops** library inside Practice (ADR 0046 Phase B): the focused list of song loops you've
/// **measured** (a command tempo set), pushed from the Practice hub. A measured loop is a trainable
/// unit — tapping a row opens its `LoopRunView` to train the same warm-up → dwell → reach → back-off
/// staircase as an exercise, against the loop's time-stretched audio. Each row also carries a button
/// per **other** mode that loop qualifies for (ADR 0138 G4) — **Ear** (ADR 0104) on anything that
/// makes a sound, **Improv** (ADR 0135) on a section flagged as a backing track — so every practice
/// mode is reachable here, not just the ramp.
///
/// No creation or deletion here: a loop belongs to its **song**, made and removed on the waveform
/// screen. This library is a read-through onto the loops worth training. Every gate is an
/// **in-memory** filter, not a SwiftData optional `#Predicate` (which starves the main thread — see
/// `PracticeRunUITests`). Sort key + direction and the search query narrow the list in memory too
/// (ADR 0056), reusing the pure `PracticeLibrarySort`.
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
    /// Whether the list is the **backing-tracks shelf** (ADR 0135 B4) — every section flagged as a bed
    /// to solo over, across every song. This is the payoff of the flag: the per-song browse can't show
    /// you what you can jam over, because the answer spans songs.
    @State private var backingOnly = false
    /// The loop + mode a row launched, driving a programmatic push (a plain `NavigationLink` can't carry
    /// the row's side-by-side buttons without the row swallowing their taps).
    @State private var launch: LoopLaunch?

    /// A loop opened in one of its practice modes (ADR 0104 / 0135). Deliberately a **mode + loop**
    /// pair rather than one case per mode: the row buttons, the long-press menu and this destination
    /// are then all driven by `LoopModeAccess.modes(for:)`, and a mode added later can't reach two of
    /// the three and be forgotten by the fourth.
    private struct LoopLaunch: Identifiable, Hashable {
        let mode: LoopRunMode
        let loop: Loop

        var id: String { "\(mode.rawValue)-\(loop.uid)" }
    }

    /// The loops in scope before search and favourites narrow them. Three listings, in priority order:
    ///
    /// - **Backing tracks** — the flagged shelf, and it must stand on its own. A backing track needs no
    ///   command tempo (ADR 0135 B2), so filtering the *measured* list by the flag would hide exactly
    ///   the loops a player flags and never measures: the shelf reads from every loop.
    /// - **All loops** — the deliberate widening past the trainer gate (ADR 0138 G4).
    /// - The default: the **trainer** gate, because this list *is* the practice library and admitting
    ///   every scratch region a player ever dragged would drown it.
    private var loopsInScope: [Loop] {
        if backingOnly { return allLoops.filter { LoopModeAccess.allows(.improvise, $0) } }
        return showAllLoops ? allLoops : allLoops.filter { LoopModeAccess.allows(.trainer, $0) }
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

    /// What the **backing-tracks shelf** says when it's empty — the one empty state that has to teach
    /// a feature, since the shelf is populated by a flag the player sets somewhere else entirely.
    private var emptyShelfMessage: String {
        "No backing tracks yet. Open a loop's settings from the waveform and turn on Backing track — "
        + "a section with no vocal, over a whole number of bars, makes the best bed to solo over."
    }

    private func fields(for loop: Loop) -> LoopSortFields {
        LoopSortFields(name: loop.name, songTitle: loop.song?.title ?? "",
                       command: loop.command, mastery: loop.mastery)
    }

    var body: some View {
        List {
            if backingOnly && visibleLoops.isEmpty && searchText.isEmpty && !favoritesOnly {
                emptyRow(emptyShelfMessage)
            } else if !hasMeasuredLoops && !showAllLoops && !backingOnly {
                emptyRow(emptyStateMessage)
            } else if visibleLoops.isEmpty {
                emptyRow(favoritesOnly
                         ? "No favourite loops yet. Swipe or hold a loop and tap Favourite to pin it."
                         : searchText.isEmpty
                           ? "No loops yet. Open a song and draw one on the waveform."
                           : "No loops match “\(searchText)”.")
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
        .navigationTitle(backingOnly ? "Backing tracks" : "Loops")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Loops and songs")
        // One fixed-width trailing control for sort + filters, matching the exercise and routine
        // libraries so the inline title centres against the back button alone (`LibraryOptionsMenu`).
        .toolbar {
            if hasAnyLoops {
                ToolbarItem(placement: .topBarTrailing) {
                    LibraryOptionsMenu(favoritesOnly: $favoritesOnly,
                                       widenFilter: $showAllLoops,
                                       widenFilterLabel: "Show all loops",
                                       narrowFilter: $backingOnly,
                                       sortControls: {
                        LibrarySortPickers(sortKey: $sortKey, ascending: $sortAscending)
                    })
                }
            }
        }
        .navigationDestination(item: $launch) { launch in
            switch launch.mode {
            case .trainer:
                LoopRunView(loop: launch.loop)
            case .ear:
                EarTrainingScreen(loop: launch.loop)
            case .improvise:
                ImproviseScreen(loop: launch.loop)
            }
        }
    }

    private func emptyRow(_ message: String) -> some View {
        Text(message)
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
            .listRowBackground(PocketColor.background)
    }

    /// A loop row, offering **exactly the modes that loop qualifies for** (ADR 0138 G4). Sibling
    /// buttons rather than nested ones, each with a non-default style, so the List routes each tap
    /// to its own target instead of firing the whole row.
    ///
    /// The trainer is the row body; every other qualifying mode is a trailing button. So Ear appears
    /// on anything audible and **Improv only on a flagged backing track** (ADR 0135 B8a) — the
    /// asymmetry is the flag's payoff, and a row that isn't a backing track shouldn't offer an
    /// affordance that leads to a bad bed.
    ///
    /// With "Show all loops" on, an unmeasured loop appears with **no trainer target** — its summary
    /// is inert text stating what it's missing, and only the mode buttons are live. Offering a tap
    /// that opens a ramp with nothing to anchor it would be the same category of mistake ADR 0138
    /// fixes, one screen further along.
    @ViewBuilder
    private func loopRow(_ loop: Loop) -> some View {
        HStack(spacing: 12) {
            if LoopModeAccess.allows(.trainer, loop) {
                Button {
                    launch = LoopLaunch(mode: .trainer, loop: loop)
                } label: {
                    summary(loop).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                summary(loop)
            }

            ForEach(secondaryModes(for: loop)) { mode in
                modeButton(mode, loop)
            }
        }
    }

    /// The modes a row offers as a **button** — everything the loop qualifies for except the trainer,
    /// which is the row body itself.
    private func secondaryModes(for loop: Loop) -> [LoopRunMode] {
        LoopModeAccess.modes(for: loop).filter { $0 != .trainer }
    }

    private func modeButton(_ mode: LoopRunMode, _ loop: Loop) -> some View {
        Button {
            launch = LoopLaunch(mode: mode, loop: loop)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: mode.symbolName)
                    .font(.futura(.body))
                Text(mode.rowLabel)
                    .font(.futura(.caption2))
            }
            .foregroundStyle(PocketColor.practice)
            .padding(.leading, 4)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(mode.label) — \(displayName(loop))")
    }

    /// The row's unit summary. An unmeasured loop has no command range to state, so it says what it
    /// needs — and what it can still do — instead of rendering "Command 0% → 0%", which would read as
    /// a measurement. The "still do" half is built from the modes it qualifies for, so a flagged
    /// backing track doesn't get told it's for ear training only.
    private func summary(_ loop: Loop) -> some View {
        HStack {
            PracticeUnitRow(title: displayName(loop),
                            context: loop.song?.title,
                            progress: LoopModeAccess.allows(.trainer, loop)
                                ? "Command \(LoopCommandRamp.percent(loop.command))% → "
                                  + "\(LoopCommandRamp.percent(loop.targetSpeed))%"
                                : unmeasuredSummary(loop),
                            isFavorite: loop.isFavorite)
            Spacer(minLength: 0)
        }
    }

    private func unmeasuredSummary(_ loop: Loop) -> String {
        let modes = secondaryModes(for: loop).map { $0.label.lowercased() }
        guard !modes.isEmpty else { return "No command tempo yet" }
        return "No command tempo yet — \(modes.formatted(.list(type: .and)))"
    }

    private func displayName(_ loop: Loop) -> String {
        loop.name.isEmpty ? "Untitled loop" : loop.name
    }

    /// A loop's long-press actions (Slice 3): its practice modes, so each is reachable from the menu
    /// as well as from the row's tap targets.
    ///
    /// **No Delete here, deliberately** — a loop belongs to its song and is removed on the waveform
    /// where it was drawn (this library is a read-through, see the type doc). The shared modifier
    /// takes an optional delete precisely so a list can decline it rather than inventing a second
    /// owner for the same object.
    ///
    /// Built from `LoopModeAccess.modes(for:)` rather than listed by hand, so the menu and the row's
    /// buttons can't disagree about what a loop can do — and so a mode added later appears in both
    /// the moment its precondition is stated.
    private func menuItems(for loop: Loop) -> [PocketRowMenuItem] {
        LoopModeAccess.modes(for: loop).map { mode in
            PocketRowMenuItem(mode.label, systemImage: mode.symbolName) {
                launch = LoopLaunch(mode: mode, loop: loop)
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
