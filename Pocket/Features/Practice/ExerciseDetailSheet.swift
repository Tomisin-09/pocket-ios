import SwiftData
import SwiftUI

/// A **read-only reference sheet** for one exercise (V1 feedback #2; ADR 0077): the place to read —
/// and lightly annotate — what an exercise *is*, kept entirely separate from tempo tuning and content
/// authoring. Neither tempo nor the drill's shape is editable here anymore (ADR 0077 pulled both
/// out): tempo is tuned on the run screen (and, in a routine, on the block surface), and the
/// content/shape editor moved to the board's "Edit shape" sheet (`ExerciseShapeSheet`). This sheet
/// shows an editable **description** (the model's `notes`), and behind its rows the self-rated
/// **mastery**, the linked songs, the references, the folders, and the meter, skills and read-only
/// **template** (ADR 0068, immutable). Reached from the exercise run screen's nav bar (ⓘ). The routine-staircase
/// preview was dropped as redundant (device feedback 2026-07-11) — the staircase already lives on the
/// run screen where you tune it.
///
/// Editable: **only** description and mastery — each committed on Done / dismiss (a no-op when
/// unchanged) so a quick open-and-close never writes. Tempo, routine shape, and the drill's content
/// are tuned elsewhere.
///
/// Grouped in the categories every detail sheet shares (ADR 0258): **About** — the description — stays
/// on the sheet, and Progress, Songs, References, Folders and Feel & skills are rows that each say what
/// is behind them (`+Categories`), pushing screens that raise their own presentations.
struct ExerciseDetailSheet: View {
    let exercise: Exercise

    /// Where a tapped song on the **Songs** screen goes (ADR 0172). The song player is not a screen
    /// this sheet can host: it rotates (ADR 0042 — the one screen that does) and holds a keep-awake
    /// lease, and neither survives being run inside a sheet. So the host dismisses this sheet first
    /// and pushes the player onto its own stack.
    ///
    /// `nil` — the default — leaves the rows exactly as they were: plain, unlinked text. Three of
    /// this sheet's four hosts pass nothing, because they are *mid-practice* surfaces (a running
    /// drill, a routine block, a freeform run) where swapping a rotating player in over the top is
    /// not a link, it's a trapdoor. Only the exercise library wires it.
    var onOpenSong: ((Song) -> Void)?

    @Environment(\.dismiss) private var dismiss
    // Internal, not private: a same-module extension in another file cannot see `private`.
    @Environment(\.modelContext) var modelContext
    /// The whole practice log, oldest first (ADR 0117) — filtered to *this* drill in memory rather
    /// than by a `#Predicate` on the optional `unitUID`, which is the documented way to starve the
    /// main thread (`docs/swiftdata-gotchas.md`). The log grows a handful of rows per session, so the
    /// full fetch is cheap; it becomes worth revisiting when a Progress screen queries it per render.
    @Query(sort: \PracticeRun.startedAt) private var practiceRuns: [PracticeRun]
    /// The description, held locally and committed on Done. **Not `private`** because the share
    /// control reads it: a drill handed over while a description sits uncommitted must carry the
    /// words on screen, not the ones in the store (ADR 0209 D3). See `ExerciseDetailSheet+Share`.
    @State var notes: String
    /// The exercise's self-rated mastery (0–5, `nil` = unrated), held locally and committed on
    /// Done — the planner's dueScore *need* signal (V2 planner Slice 1, ADR 0070: self-set, never
    /// measured). Mirrors the loop editor's mastery dots. Internal, not private: Progress
    /// (`+Categories`) binds it.
    @State var mastery: Int?

    /// The log as plain values — every stat is computed over `[SessionRecord]`, never over `@Model`s,
    /// so the trajectory math stays SwiftData-free and unit-tested (ADR 0117).
    var sessionRecords: [SessionRecord] { practiceRuns.map(\.record) }

    init(exercise: Exercise, onOpenSong: ((Song) -> Void)? = nil) {
        self.exercise = exercise
        self.onOpenSong = onOpenSong
        _notes = State(initialValue: exercise.notes)
        _mastery = State(initialValue: exercise.mastery)
    }

    var body: some View {
        NavigationStack {
            KeyboardFollowingScroll {
                Form {
                    // A freeform block's authoring is its own thing (ADR 0136): its instructions *are*
                    // the exercise, and it carries an optional click instead of a Feel row about a
                    // rhythm it doesn't have. Shared with the routine editor's block surface so the
                    // two can't drift.
                    if isFreeform {
                        FreeformInstructionsSection(exercise: exercise)
                        FreeformMetronomeSection(exercise: exercise)
                    } else {
                        descriptionSection
                    }
                    categoriesSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                shareToolbarItem
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitNotes(); commitMastery()
                        dismiss()
                    }
                }
            }
        }
        // On the stack, not its root: a pushed screen inherits the stack's environment and none of the
        // root's modifiers, so a tint on the root left every category screen in the system blue.
        .tint(PocketColor.practice)
    }

    /// A freeform block's `notes` is not a note *about* an exercise — it **is** the exercise
    /// (ADR 0136 F2), so it gets its own sections rather than a re-worded Description. The storage is
    /// identical; what changes is what it means to the player, and what belongs beside it.
    var isFreeform: Bool { exercise.template == .freeform }

    // MARK: - Description (editable) + tags

    private var descriptionSection: some View {
        Section {
            TextField("Technique cues, target feel, where it's from…", text: $notes, axis: .vertical)
                .lineLimit(3...8)
            // Still here. ADR 0210's first cut took these out, on the grounds that its backfill had
            // copied every tag into a folder; with the backfill gone they are the only place a
            // drill's tags are visible at all, and removing them would have lost information with
            // nothing put in its place.
            if !exercise.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(exercise.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.futura(.caption, weight: .semibold))
                            .foregroundStyle(PocketColor.practice)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(PocketColor.practice.opacity(0.16)))
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("About")
        } footer: {
            Text("A note to yourself about the drill — saved with the exercise.")
        }
    }

    // MARK: - Helpers

    /// Persist an edited description, trimmed. A no-op when unchanged, so opening and closing the
    /// sheet without touching the field never writes to the store.
    func commitNotes() {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != exercise.notes else { return }
        exercise.notes = trimmed
        try? modelContext.save()
    }

    /// Persist an edited mastery rating on Done, only when it differs from what's stored — a
    /// deliberate self-assessment (ADR 0070), never computed from playing.
    func commitMastery() {
        guard mastery != exercise.mastery else { return }
        exercise.rateMastery(mastery)
        try? modelContext.save()
    }
}

#Preview("Exercise detail — strumming") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let exercise = Exercise(name: "Folk strum", currentTempo: 70, commandTempo: 96,
                            template: .strumming, tags: ["rhythm", "strumming"],
                            notes: "Keep the hand swinging in steady eighths.")
    exercise.setStrumPattern(.folk)
    container.mainContext.insert(exercise)
    return ExerciseDetailSheet(exercise: exercise)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
