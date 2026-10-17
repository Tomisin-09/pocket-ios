import SwiftData
import SwiftUI

/// **Practice** — a top-level destination (ADR 0046), peer to the song library and the metronome,
/// reached from Home. The home for everything you *train*.
///
/// Since ADR 0257 it is **four shelves**, each one fixed-height row with an **All N ›** link to its
/// library, top to bottom:
///
/// - **Today's session** — the planner's door, carrying the long-term goals that shape it and the
///   one session you started and didn't save (`+Today`).
/// - **Routines** — up to three saved routines, favourites first, then New routine (`+Shelves`).
///   Second, so the sessions you built aren't overshadowed by the units they're built from.
/// - **Exercises** — the picker's categories you have drills in, as two rows of tiles.
/// - **Loops** — the measured loops, grouped by song.
///
/// Anything past a shelf's width is a sideways swipe. The rules for what goes on each live in the
/// pure `PracticeHubShelves`; this view only draws them.
///
/// Relies on an ambient `NavigationStack` (pushed from Home, like `LibraryView`) rather than owning
/// one, so the library pushes land in Home's navigation.
struct PracticeView: View {
    @Environment(\.modelContext) var context
    /// Read only for a routine card's *Next:* line (ADR 0257 D3). Optional so a preview or a test
    /// host without one still draws the hub, with no reminder lines.
    @Environment(PracticeReminder.self) var practiceReminder: PracticeReminder?
    @Query var exercises: [Exercise]
    @Query var allLoops: [Loop]
    @Query var routines: [Routine]
    @Query var longTermGoals: [LongTermGoal]
    /// For the goal editor's target-song picker.
    @Query var songs: [Song]
    /// The practice log, reduced once per redraw into each routine's history — the same reduction
    /// the Routines library makes, so a card and its library row say the same thing.
    @Query var runs: [PracticeRun]

    /// Notification permission as last read: a card names its next reminder only when it can arrive
    /// (ADR 0186 D7). `nil` until read.
    @State var notificationPermission: NotificationPermission?
    /// The routine a card's ▶ started, presented full-screen as the Routines library does.
    @State var playing: Routine?
    /// The New exercise tile's create sheet (`NewExerciseFlow`).
    @State var creatingExercise = false
    /// A goal chip's editor. Presented by stable identity, never `PersistentIdentifier` (ADR 0090).
    @State var editingGoal: StableRef<LongTermGoal>?
    @State var addingGoal = false

    /// Behind the plan (ADR 0256 D3): every route here meets the same wall, and nothing below is built
    /// until the plan is on.
    var body: some View {
        PlanGated(.practice) { gatedScreen }
    }

    @ViewBuilder private var gatedScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                todayCard
                    .padding(.horizontal, 16)
                routinesShelf
                exercisesShelf
                loopsShelf
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
            // Cap to a readable column at regular width (iPad / landscape); a no-op at compact width,
            // dormant on the iPhone-only v1 build (ADR 0105).
            .readableWidth()
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .task { notificationPermission = await NotificationAuthorization.current() }
        // Every presentation hangs off the screen's root, never off a card inside a shelf (the iOS 18
        // trap where a presentation on a row loses its write).
        .fullScreenCover(item: $playing) { RoutinePlayerView(routine: $0) }
        .newExerciseFlow(isPresented: $creatingExercise)
        .sheet(isPresented: $addingGoal) {
            LongTermGoalEditorView(existing: nil, songs: songs, newGoalOrder: longTermGoals.count)
        }
        .sheet(item: $editingGoal) { ref in
            LongTermGoalEditorView(existing: ref.value, songs: songs)
        }
    }

    // MARK: - Derived

    /// Saved routines only (ADR 0243 D2): the shelf and its count are about what you keep.
    var savedRoutines: [Routine] { Routine.saved(routines) }

    /// The loops the Loops library lists by default — the measured ones (ADR 0138's trainer gate) — so
    /// a tile's count and **All N** both match what the library shows when it opens.
    var measuredLoops: [Loop] { allLoops.filter { LoopModeAccess.allows(.trainer, $0) } }

    /// Each routine's sittings and last-practised date, in one pass over the log.
    var routineHistory: (counts: [UUID: Int], dates: [UUID: Date]) {
        let records = runs.map(\.record)
        return (PracticeLog.routineSessionCounts(in: records), PracticeLog.routineLastPractised(in: records))
    }

    /// The **All N ›** text: the number, or just `All` when there is nothing to count but the library
    /// is still worth opening (to receive, to generate, to show every loop).
    func allLinkText(_ count: Int) -> String {
        count > 0 ? "All \(count)" : "All"
    }
}
