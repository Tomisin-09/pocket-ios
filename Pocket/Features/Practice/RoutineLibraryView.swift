import SwiftData
import SwiftUI

/// The **Routines** library inside Practice (ADR 0066): the list of hand-built practice sessions,
/// pushed from the Practice hub. Owns routine **creation** (`+` → a new empty routine you drop
/// straight into the editor), **playing** (the ▶ on each row runs the auto-advancing player, slice
/// 3), **editing** (tapping the row body), and **deletion** (swipe).
///
/// Relies on the ambient `NavigationStack` (Practice → Home's stack), like the exercise and
/// loop libraries. Sorted newest-first in memory so `@Query` stays unsorted and deletion
/// indexes the displayed order.
struct RoutineLibraryView: View {
    @Environment(\.modelContext) private var context
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
        routines
            .filter { !favoritesOnly || $0.isFavorite }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        List {
            if routines.isEmpty {
                Text("No routines yet. Tap + to build one — an ordered run of exercises and "
                     + "loops you work through in a sitting.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else if ordered.isEmpty {
                Text("No favourite routines yet. Swipe a routine and tap Favourite to pin it.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(ordered) { routine in
                    row(for: routine)
                        .listRowBackground(PocketColor.background)
                        .swipeActions(edge: .leading) { favoriteButton(for: routine) }
                }
                .onDelete(perform: delete)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: generateQuickSession) {
                    Image(systemName: isPro ? "wand.and.stars" : "lock.fill")
                }
                .tint(PocketColor.practice)
                .disabled(isPro && !exercises.contains { $0.template != .warmup })
                .accessibilityLabel("Generate a quick session")
            }
            if !routines.isEmpty {
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
        let runnable = AccessPolicy.canRunRoutine(
            isPro: isPro,
            isFreeTasteRoutine: AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug))
        return HStack(spacing: 14) {
            Button {
                guard runnable else { return presentPaywall(.routine) }
                playing = routine
                haptic(.light)
            } label: {
                Image(systemName: runnable ? "play.circle.fill" : "lock.circle.fill")
                    .font(.futura(.title2))
                    .foregroundStyle(runnable ? PocketColor.practice : PocketColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(runnable
                                ? "Play \(routine.name.isEmpty ? "routine" : routine.name)"
                                : "Locked — Red Moon Pro")

            Button {
                guard AccessPolicy.canAuthorRoutine(isPro: isPro) else {
                    return presentPaywall(.routine)
                }
                editing = routine
                haptic(.light)
            } label: {
                rowBody(for: routine, runnable: runnable)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    /// The tappable half of a row: name (+ favourite star), block summary, and the trailing
    /// entitlement affordances. The capsule marks a routine that can't even be *run* — so the curated
    /// free-taste routine never wears one — while the trailing glyph tracks this half's own action
    /// (edit), which is Pro for every routine, freebie included.
    private func rowBody(for routine: Routine, runnable: Bool) -> some View {
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
            if !runnable { proBadge }
            Image(systemName: isPro ? "chevron.right" : "lock.fill")
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

    /// The leading-swipe favourite toggle for a routine (ADR 0119).
    private func favoriteButton(for routine: Routine) -> some View {
        Button {
            routine.isFavorite.toggle()
            haptic(.light)
        } label: {
            Label(routine.isFavorite ? "Unfavourite" : "Favourite",
                  systemImage: routine.isFavorite ? "star.slash" : "star")
        }
        .tint(PocketColor.practice)
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

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(ordered[index]) }
        haptic(.medium)
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
