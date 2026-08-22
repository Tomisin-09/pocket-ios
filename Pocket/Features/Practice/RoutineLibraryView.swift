import SwiftData
import SwiftUI

/// The **Routines** library inside Practice (ADR 0066): the list of hand-built practice sessions,
/// pushed from the Practice hub. Owns routine **creation** (`+` → a new empty routine you drop
/// straight into the editor), **playing** (the ▶ on each row runs the auto-advancing player, slice
/// 3), **editing** (tapping the row body), **duplication** and **deletion**.
///
/// Holding a row opens the shared menu (Play · Edit · Duplicate · Favourite · Delete) via
/// `.pocketRowActions`, matching every other list in the app (Slice 3); delete is deferred behind
/// an Undo toast, so `ordered` filters out rows awaiting their delete.
///
/// Relies on the ambient `NavigationStack` (Practice → Home's stack), like the exercise and
/// loop libraries. **Searched and sorted in memory** (ADR 0178) via the pure `PracticeLibrarySort`,
/// so `@Query` stays unsorted and deletion indexes the displayed order. Row rendering lives in
/// `RoutineLibraryView+Row.swift`.
struct RoutineLibraryView: View {
    @Environment(\.modelContext) private var context
    /// Deferred, undoable row deletion (Slice 3). **Owned here, not by the modifier**: this view
    /// reads `isPending` itself so `ordered` can hide a row while its Undo window is open, and a
    /// modifier applied inside `body` can only publish to its descendants.
    @State private var rowDeletion = RowDeletionCoordinator()
    /// Entitlement + the shared paywall (ADR 0112). **Routines are Pro**, apart from the one curated
    /// free-taste routine a free player may run (but not edit).
    @Environment(\.isPro) var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    @Query private var routines: [Routine]
    /// Every exercise in the library — the raw material the planner's Quick session draws from
    /// (V2 planner Slice 1). Ranked by dueness, warm-up LRU-picked; no goals yet.
    @Query private var exercises: [Exercise]
    /// The practice log, for the per-row tally (ADR 0173). Fetched whole and reduced **once** into
    /// `sessionCounts` below — a `#Predicate` on the optional `routineUID` is the documented way to
    /// starve the main thread, and a per-row `routineHistory` call would rescan the log for every
    /// routine on screen.
    @Query private var runs: [PracticeRun]

    /// Drives the push into a fresh-routine editor. The new routine isn't created here — the
    /// editor builds it in its own sandbox and only persists it on Save, so an abandoned
    /// "New routine" never lands in the library.
    @State private var creatingNew = false
    /// The routine being edited (row-body tap) — pushed as a detail; `nil` when none.
    @State private var editing: Routine?
    /// The routine being played (▶) — presented full-screen over the library; `nil` when none.
    @State private var playing: Routine?
    /// A freshly-generated Quick session awaiting review — pushed as a **provisional** detail
    /// (nothing persists until the user Saves or Starts it, V2 planner Slice 1); `nil` when none.
    @State private var quickDraft: QuickSessionDraft?
    /// Whether the list is narrowed to favourited routines (ADR 0119) — a session toggle, not persisted.
    @State private var favoritesOnly = false
    /// Sort key + direction, persisted across launches (ADR 0178), defaulting to the newest-first
    /// order this library had when it had no choice — so an existing player's list is unchanged
    /// until they change it.
    @AppStorage("routineLibrarySort") private var sortKey: RoutineSortKey = .recentlyAdded
    @AppStorage("routineLibrarySortAscending") private var sortAscending = true
    @State private var searchText = ""

    /// The routines on screen: narrowed by the favourites filter (ADR 0119) and the search query,
    /// then ordered by the chosen key (ADR 0178).
    ///
    /// **It takes the history maps rather than reading them**, because two of the four sort keys
    /// need the practice log and `body` has already reduced it once for the rows. A computed
    /// property here would rescan the whole log a second time on every redraw — the cost ADR 0173 D6
    /// went out of its way to pay only once.
    private func ordered(facts: RoutineListFacts) -> [Routine] {
        let matched = presentRoutines.filter {
            (!favoritesOnly || $0.isFavorite)
                && PracticeLibrarySort.routineMatches(fields(for: $0, facts: facts),
                                                      query: searchText)
        }
        return PracticeLibrarySort.sortedRoutines(matched, by: sortKey, ascending: sortAscending,
                                                  fields: { fields(for: $0, facts: facts) })
    }

    /// One routine's sort-relevant fields, read out of the already-computed `facts`.
    private func fields(for routine: Routine, facts: RoutineListFacts) -> RoutineSortFields {
        RoutineSortFields(name: displayName(routine), dateAdded: routine.dateAdded,
                          notes: routine.notes, lastPractised: facts.dates[routine.uid],
                          estimatedMinutes: facts.minutes[routine.uid] ?? 0)
    }

    /// The message shown when the library has routines but none is on screen — search-aware, so a
    /// query with no hits doesn't read as "you have no favourites" (and vice versa).
    private var noMatchMessage: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No routines match “\(searchText)”."
        }
        return "No favourite routines yet. Swipe or hold a routine and tap Favourite to pin it."
    }

    /// The routines actually on screen — everything except rows whose delete is pending behind the
    /// Undo toast (Slice 3). The empty state reads from here too, so deleting your last routine says
    /// "no routines yet" rather than "no favourites".
    private var presentRoutines: [Routine] {
        routines.filter { !rowDeletion.isPending($0.uid) }
    }

    var body: some View {
        List {
            // Reduced once here and handed down — to the sort, to the rows, and to the length
            // each row now states (ADR 0178). Every one of the three is a whole-collection walk:
            // rebuilding them per row would rescan the practice log, and re-price every block of
            // every routine, on every redraw.
            let facts = listFacts
            let visible = ordered(facts: facts)
            if presentRoutines.isEmpty {
                Text("No routines yet. Tap + to build one — an ordered run of exercises and "
                     + "loops you work through in a sitting.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else if visible.isEmpty {
                Text(noMatchMessage)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(visible) { routine in
                    row(for: routine, facts: facts)
                        .listRowBackground(PocketColor.background)
                        .pocketRowActions(displayName(routine),
                                          tint: PocketColor.practice,
                                          menu: menuItems(for: routine),
                                          favorite: favorite(for: routine),
                                          delete: deletion(for: routine))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        // Deferred delete + the Undo toast for every row on this screen (Slice 3).
        .pocketRowUndoHost(rowDeletion)
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Routines")
        // Leading is the back button alone. The session generator moves off the bar and into the
        // shared options menu — as a *labelled* row rather than a bare wand, which also gives its
        // disabled and locked states somewhere to read (`LibraryOptionsMenu`). The sort pickers
        // join it (ADR 0178), which is what made this the last library with a fixed order.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LibraryOptionsMenu(favoritesOnly: $favoritesOnly,
                                   showsFavoritesFilter: !presentRoutines.isEmpty, actions: {
                    Button(action: generateQuickSession) {
                        Label("Generate a quick session",
                              systemImage: isPro ? "wand.and.stars" : "lock.fill")
                    }
                    .disabled(isPro && !exercises.contains { $0.template != .warmup })
                }, sortControls: {
                    LibrarySortPickers(sortKey: $sortKey, ascending: $sortAscending)
                })
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Building a routine is authoring — Pro, with no free-tier escape (ADR 0112).
                    guard AccessPolicy.canAuthorRoutine(isPro: isPro) else {
                        return presentPaywall(.routine(.new))
                    }
                    creatingNew = true
                    haptic(.light)
                } label: {
                    Image(systemName: isPro ? "plus" : "lock.fill")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel(isPro ? "New routine" : "New routine — Red Moon Pro")
            }
        }
        .navigationDestination(item: $editing) { routine in
            RoutineDetailView(container: context.container, existing: routine)
        }
        .navigationDestination(isPresented: $creatingNew) {
            RoutineDetailView(container: context.container, existing: nil)
        }
        .navigationDestination(item: $quickDraft) { draft in
            RoutineDetailView(container: context.container,
                              generatedSession: draft.blocks, defaultName: draft.name,
                              targetMinutes: draft.targetMinutes)
        }
        .fullScreenCover(item: $playing) { routine in
            RoutinePlayerView(routine: routine)
        }
    }

    /// Run the session — gated on `canRunRoutine`, so the curated free-taste routine plays for a
    /// free player (ADR 0112). Shared by the ▶ button and the row menu's Play.
    func play(_ routine: Routine) {
        let isDemo = AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug)
        guard AccessPolicy.canRunRoutine(isPro: isPro, isFreeTasteRoutine: isDemo) else {
            return presentPaywall(.routine(.play))
        }
        playing = routine
        haptic(.light)
    }

    /// Open the editor. The demo exception (ADR 0112): the curated free-taste routine opens for a
    /// free player too — read-only, then rearrange-only under Edit. Adding stays Pro. Shared by the
    /// row-body tap and the row menu's Edit.
    func edit(_ routine: Routine) {
        let isDemo = AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug)
        guard AccessPolicy.canEditRoutine(isPro: isPro, isFreeTasteRoutine: isDemo) else {
            return presentPaywall(.routine(.edit))
        }
        editing = routine
        haptic(.light)
    }

    private func displayName(_ routine: Routine) -> String {
        routine.name.isEmpty ? "Untitled routine" : routine.name
    }

    /// The routine's own long-press actions (Slice 3). Play and Edit mirror the row's two buttons
    /// — the menu is a discoverable second route to the same gated calls, not a bypass.
    private func menuItems(for routine: Routine) -> [PocketRowMenuItem] {
        [PocketRowMenuItem("Play", systemImage: "play.circle") { play(routine) },
         PocketRowMenuItem("Edit", systemImage: "pencil") { edit(routine) },
         PocketRowMenuItem("Duplicate", systemImage: "plus.square.on.square") { duplicate(routine) }]
    }

    private func favorite(for routine: Routine) -> PocketRowFavorite {
        PocketRowFavorite(isFavorite: routine.isFavorite) { routine.isFavorite.toggle() }
    }

    private func deletion(for routine: Routine) -> PocketRowDelete {
        PocketRowDelete(id: routine.uid, name: displayName(routine)) { context.delete(routine) }
    }

    /// Fork a session into an editable copy — the point of it is variation ("Tuesday, but with the
    /// legato block"), which otherwise means rebuilding the whole block list by hand (Slice 3).
    ///
    /// Duplicating composes a routine, so it takes `canAuthorRoutine` — flat Pro, no demo exception
    /// (ADR 0112): copying the free demo would otherwise mint an unlocked, editable routine. The
    /// blocks reference the **same** units; only the session is forked.
    private func duplicate(_ routine: Routine) {
        guard AccessPolicy.canAuthorRoutine(isPro: isPro) else { return presentPaywall(.routine(.duplicate)) }
        let name = CopyNaming.copyName(of: routine.name, existing: routines.map(\.name))
        let (copy, blocks) = routine.duplicated(named: name)
        context.insert(copy)
        copy.items = blocks
        haptic(.medium)
    }

    /// Everything the list derives about its routines, built **once per redraw** rather than per
    /// row (ADR 0173 D6, extended by ADR 0178 to the length).
    ///
    /// The **estimate is the same number the detail screen shows** — both go through
    /// `PracticePlanner.estimatedMinutes(forRoutine:)` — so a list sorted by length, the length
    /// printed on its rows, and the routine you then open cannot disagree with each other.
    private var listFacts: RoutineListFacts {
        let records = runs.map(\.record)
        return RoutineListFacts(
            counts: PracticeLog.routineSessionCounts(in: records),
            dates: PracticeLog.routineLastPractised(in: records),
            minutes: Dictionary(uniqueKeysWithValues: presentRoutines.map {
                ($0.uid, PracticePlanner.estimatedMinutes(forRoutine: $0))
            }))
    }

    /// Generate a Quick session (default short budget, ADR 0014 R8) from the exercise library and
    /// push it for **review** — the V2 planner's first surface (Slice 1). Nothing is persisted here:
    /// the blocks are pure, and the provisional detail screen only commits them to the library on an
    /// explicit Save or Start. The default name is dated and de-duplicated against the library.
    ///
    /// A **fifth** routine producer, and so gated like the rest (ADR 0112) — it materialises a real
    /// `Routine`, which is authoring.
    private func generateQuickSession() {
        guard AccessPolicy.canAuthorRoutine(isPro: isPro) else { return presentPaywall(.routine(.generate)) }
        let blocks = PracticePlanner.planQuickSession(length: .default, exercises: exercises)
        guard blocks.contains(where: { $0.unit != nil }) else { return }
        let name = QuickSessionNaming.defaultName(existing: routines.map(\.name), date: .now)
        quickDraft = QuickSessionDraft(blocks: blocks, name: name,
                                       targetMinutes: SessionLength.default.minutes)
        haptic(.light)
    }

}

/// What the Routines list derives about the routines on it: how many sittings each has been
/// practised in, when it last was (ADR 0173), and roughly how long it runs (ADR 0178).
///
/// One value rather than three parameters, because all three are computed together, at the same
/// moment, for the same reason — and a row that took them separately could be handed one redraw's
/// history beside another's lengths.
struct RoutineListFacts {
    let counts: [UUID: Int]
    let dates: [UUID: Date]
    let minutes: [UUID: Int]
}

/// A freshly-generated Quick session pending review — the pure `[SessionBlock]` plus its dated
/// default name. Identity is a per-generation `id` (blocks aren't `Hashable`), which is all
/// `navigationDestination(item:)` needs to push the provisional detail once.
struct QuickSessionDraft: Identifiable, Hashable {
    let id = UUID()
    let blocks: [SessionBlock]
    let name: String
    /// The length the user asked for, in minutes — lets the review screen show a soft budget (R3).
    var targetMinutes: Int?

    static func == (lhs: QuickSessionDraft, rhs: QuickSessionDraft) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview("Routines — with sessions") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Routine.self, RoutineItem.self, Exercise.self, Song.self, Loop.self, PracticeRun.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let drill = Exercise(name: "Spider", currentTempo: 60)
    container.mainContext.insert(drill)
    let routine = Routine(name: "Morning warm-up")
    routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                     RoutineItem.rest(order: 1),
                     RoutineItem.item(drill, order: 2)]
    container.mainContext.insert(routine)
    container.mainContext.insert(Routine(name: "Alt-picking builder"))
    return NavigationStack { RoutineLibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
