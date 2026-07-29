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
/// loop libraries. Sorted newest-first in memory so `@Query` stays unsorted and deletion
/// indexes the displayed order.
struct RoutineLibraryView: View {
    @Environment(\.modelContext) private var context
    /// Deferred, undoable row deletion (Slice 3). **Owned here, not by the modifier**: this view
    /// reads `isPending` itself so `ordered` can hide a row while its Undo window is open, and a
    /// modifier applied inside `body` can only publish to its descendants.
    @State private var rowDeletion = RowDeletionCoordinator()
    /// Entitlement + the shared paywall (ADR 0112). **Routines are Pro**, apart from the one curated
    /// free-taste routine a free player may run (but not edit).
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    @Query private var routines: [Routine]
    /// Every exercise in the library — the raw material the planner's Quick session draws from
    /// (V2 planner Slice 1). Ranked by dueness, warm-up LRU-picked; no goals yet.
    @Query private var exercises: [Exercise]

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

    /// Newest first — the same default sort key as the other libraries (`dateAdded`) — optionally
    /// narrowed to favourites (ADR 0119).
    private var ordered: [Routine] {
        presentRoutines
            .filter { !favoritesOnly || $0.isFavorite }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    /// The routines actually on screen — everything except rows whose delete is pending behind the
    /// Undo toast (Slice 3). The empty state reads from here too, so deleting your last routine says
    /// "no routines yet" rather than "no favourites".
    private var presentRoutines: [Routine] {
        routines.filter { !rowDeletion.isPending($0.uid) }
    }

    var body: some View {
        List {
            if presentRoutines.isEmpty {
                Text("No routines yet. Tap + to build one — an ordered run of exercises and "
                     + "loops you work through in a sitting.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else if ordered.isEmpty {
                Text("No favourite routines yet. Swipe or hold a routine and tap Favourite to pin it.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(ordered) { routine in
                    row(for: routine)
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
        // Leading is the back button alone. The session generator moves off the bar and into the
        // shared options menu — as a *labelled* row rather than a bare wand, which also gives its
        // disabled and locked states somewhere to read (`LibraryOptionsMenu`). Routines have a
        // fixed order (newest first), so the menu carries no sort pickers.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LibraryOptionsMenu(favoritesOnly: $favoritesOnly,
                                   showsFavoritesFilter: !presentRoutines.isEmpty, actions: {
                    Button(action: generateQuickSession) {
                        Label("Generate a quick session",
                              systemImage: isPro ? "wand.and.stars" : "lock.fill")
                    }
                    .disabled(isPro && !exercises.contains { $0.template != .warmup })
                })
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Building a routine is authoring — Pro, with no free-tier escape (ADR 0112).
                    guard AccessPolicy.canAuthorRoutine(isPro: isPro) else {
                        return presentPaywall(.routine)
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

    /// A routine row — a ▶ that plays the session, then a tappable name + one-line block summary
    /// that opens the editor. Two independent plain buttons so the two actions never collide.
    ///
    /// Entitlement-aware (ADR 0112), and the two halves gate **differently**: ▶ asks `canRunRoutine`
    /// (so the curated free-taste routine plays for a free player) while the body asks
    /// `canAuthorRoutine` (so that same routine still can't be *edited* — run the freebie, don't
    /// author it, exactly as the free-taste exercises behave). A routine a free player can neither run
    /// nor edit stays **visible but badged** — "locked, not hidden".
    private func row(for routine: Routine) -> some View {
        let isDemo = AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug)
        let runnable = AccessPolicy.canRunRoutine(isPro: isPro, isFreeTasteRoutine: isDemo)
        return HStack(spacing: 14) {
            Button { play(routine) } label: {
                Image(systemName: runnable ? "play.circle.fill" : "lock.circle.fill")
                    .font(.futura(.title2))
                    .foregroundStyle(runnable ? PocketColor.practice : PocketColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(runnable
                                ? "Play \(routine.name.isEmpty ? "routine" : routine.name)"
                                : "Locked — Red Moon Pro")

            Button { edit(routine) } label: {
                rowBody(for: routine, openable: runnable)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    /// Run the session — gated on `canRunRoutine`, so the curated free-taste routine plays for a
    /// free player (ADR 0112). Shared by the ▶ button and the row menu's Play.
    private func play(_ routine: Routine) {
        let isDemo = AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug)
        guard AccessPolicy.canRunRoutine(isPro: isPro, isFreeTasteRoutine: isDemo) else {
            return presentPaywall(.routine)
        }
        playing = routine
        haptic(.light)
    }

    /// Open the editor. The demo exception (ADR 0112): the curated free-taste routine opens for a
    /// free player too — read-only, then rearrange-only under Edit. Adding stays Pro. Shared by the
    /// row-body tap and the row menu's Edit.
    private func edit(_ routine: Routine) {
        let isDemo = AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug)
        guard AccessPolicy.canEditRoutine(isPro: isPro, isFreeTasteRoutine: isDemo) else {
            return presentPaywall(.routine)
        }
        editing = routine
        haptic(.light)
    }

    /// The tappable half of a row: name (+ favourite star), block summary, and the trailing
    /// entitlement affordances. `openable` means the row leads somewhere for this player — true for
    /// any routine when Pro, and for the curated demo when free. The PRO capsule and the padlock both
    /// mark the rows that don't, so the demo reads as ordinary and the rest read as locked.
    private func rowBody(for routine: Routine, openable: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(routine.name.isEmpty ? "Untitled routine" : routine.name)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    if routine.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.futura(.caption2))
                            .foregroundStyle(PocketColor.practice)
                            .accessibilityLabel("Favourite")
                    }
                }
                Text(summary(for: routine))
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.practice)
            }
            Spacer(minLength: 8)
            if !openable { proBadge }
            Image(systemName: openable ? "chevron.right" : "lock.fill")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .contentShape(Rectangle())
    }

    /// The "PRO" capsule marking a routine a free player cannot run (ADR 0112). Matches the exercise
    /// library's badge, and is deliberately absent from the curated free-taste routine, which plays.
    private var proBadge: some View {
        Text("PRO")
            .font(.futura(.caption2, weight: .bold))
            .foregroundStyle(PocketColor.background)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(PocketColor.practice))
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
        guard AccessPolicy.canAuthorRoutine(isPro: isPro) else { return presentPaywall(.routine) }
        let name = CopyNaming.copyName(of: routine.name, existing: routines.map(\.name))
        let (copy, blocks) = routine.duplicated(named: name)
        context.insert(copy)
        copy.items = blocks
        haptic(.medium)
    }

    /// "3 units · 1 rest" — the routine's shape at a glance; "Empty" before any blocks.
    private func summary(for routine: Routine) -> String {
        let items = routine.items
        guard !items.isEmpty else { return "Empty" }
        let units = items.filter(\.kind.carriesUnit).count
        let rests = items.count - units
        var parts = ["\(units) unit\(units == 1 ? "" : "s")"]
        if rests > 0 { parts.append("\(rests) rest\(rests == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    /// Generate a Quick session (default short budget, ADR 0014 R8) from the exercise library and
    /// push it for **review** — the V2 planner's first surface (Slice 1). Nothing is persisted here:
    /// the blocks are pure, and the provisional detail screen only commits them to the library on an
    /// explicit Save or Start. The default name is dated and de-duplicated against the library.
    ///
    /// A **fifth** routine producer, and so gated like the rest (ADR 0112) — it materialises a real
    /// `Routine`, which is authoring.
    private func generateQuickSession() {
        guard AccessPolicy.canAuthorRoutine(isPro: isPro) else { return presentPaywall(.routine) }
        let blocks = PracticePlanner.planQuickSession(minutes: SessionLength.default.minutes,
                                                      exercises: exercises)
        guard blocks.contains(where: { $0.unit != nil }) else { return }
        let name = QuickSessionNaming.defaultName(existing: routines.map(\.name), date: .now)
        quickDraft = QuickSessionDraft(blocks: blocks, name: name,
                                       targetMinutes: SessionLength.default.minutes)
        haptic(.light)
    }

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
        for: Routine.self, RoutineItem.self, Exercise.self, Song.self, Loop.self,
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
