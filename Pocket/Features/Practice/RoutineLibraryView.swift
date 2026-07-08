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

    /// Newest first — the same default sort key as the other libraries (`dateAdded`).
    private var ordered: [Routine] {
        routines.sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        List {
            if routines.isEmpty {
                Text("No routines yet. Tap + to build one — an ordered run of exercises and "
                     + "loops you work through in a sitting.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(ordered) { routine in
                    row(for: routine)
                        .listRowBackground(PocketColor.background)
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
                    Image(systemName: "wand.and.stars")
                }
                .tint(PocketColor.practice)
                .disabled(!exercises.contains { $0.template != .warmup })
                .accessibilityLabel("Generate a quick session")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { creatingNew = true; haptic(.light) } label: { Image(systemName: "plus") }
                    .tint(PocketColor.practice)
                    .accessibilityLabel("New routine")
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
                              generatedSession: draft.blocks, defaultName: draft.name)
        }
        .fullScreenCover(item: $playing) { routine in
            RoutinePlayerView(routine: routine)
        }
    }

    /// A routine row — a ▶ that plays the session, then a tappable name + one-line block summary
    /// that opens the editor. Two independent plain buttons so the two actions never collide.
    private func row(for routine: Routine) -> some View {
        HStack(spacing: 14) {
            Button { playing = routine; haptic(.light) } label: {
                Image(systemName: "play.circle.fill")
                    .font(.futura(.title2))
                    .foregroundStyle(PocketColor.practice)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(routine.name.isEmpty ? "routine" : routine.name)")

            Button { editing = routine; haptic(.light) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.name.isEmpty ? "Untitled routine" : routine.name)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                        Text(summary(for: routine))
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.practice)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
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
    private func generateQuickSession() {
        let blocks = PracticePlanner.planQuickSession(minutes: SessionLength.default.minutes,
                                                      exercises: exercises)
        guard blocks.contains(where: { $0.unit != nil }) else { return }
        let name = QuickSessionNaming.defaultName(existing: routines.map(\.name), date: .now)
        quickDraft = QuickSessionDraft(blocks: blocks, name: name)
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
