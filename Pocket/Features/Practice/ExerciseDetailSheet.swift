import SwiftData
import SwiftUI

/// A **read-only reference sheet** for one exercise (V1 feedback #2; ADR 0077): the place to read —
/// and lightly annotate — what an exercise *is*, kept entirely separate from tempo tuning and content
/// authoring. Neither tempo nor the drill's shape is editable here anymore (ADR 0077 pulled both
/// out): tempo is tuned on the run screen (and, in a routine, on the block surface), and the
/// content/shape editor moved to the board's "Edit shape" sheet (`ExerciseShapeSheet`). This sheet
/// surfaces, top to bottom, an editable **description** (the model's `notes`), the self-rated
/// **mastery**, the meter + subdivision (**Feel**), and — at the bottom — the read-only **template**
/// chip (ADR 0068, immutable). Reached from the exercise run screen's nav bar (ⓘ). The routine-staircase
/// preview was dropped as redundant (device feedback 2026-07-11) — the staircase already lives on the
/// run screen where you tune it.
///
/// Editable: **only** description and mastery — each committed on Done / dismiss (a no-op when
/// unchanged) so a quick open-and-close never writes. Tempo, routine shape, and the drill's content
/// are tuned elsewhere.
struct ExerciseDetailSheet: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// Every song, to offer in the link picker (ADR 0111). Sorted by title, matching the library.
    @Query(sort: \Song.title) private var allSongs: [Song]
    /// The whole practice log, oldest first (ADR 0117) — filtered to *this* drill in memory rather
    /// than by a `#Predicate` on the optional `unitUID`, which is the documented way to starve the
    /// main thread (`docs/swiftdata-gotchas.md`). The log grows a handful of rows per session, so the
    /// full fetch is cheap; it becomes worth revisiting when a Progress screen queries it per render.
    @Query(sort: \PracticeRun.startedAt) private var practiceRuns: [PracticeRun]
    @State private var showingSongPicker = false
    @State private var notes: String
    /// The exercise's self-rated mastery (0–5, `nil` = unrated), held locally and committed on
    /// Done — the planner's dueScore *need* signal (V2 planner Slice 1, ADR 0070: self-set, never
    /// measured). Mirrors the loop editor's mastery dots.
    @State private var mastery: Int?

    /// The log as plain values — every stat is computed over `[SessionRecord]`, never over `@Model`s,
    /// so the trajectory math stays SwiftData-free and unit-tested (ADR 0117).
    private var sessionRecords: [SessionRecord] { practiceRuns.map(\.record) }

    init(exercise: Exercise) {
        self.exercise = exercise
        _notes = State(initialValue: exercise.notes)
        _mastery = State(initialValue: exercise.mastery)
    }

    var body: some View {
        NavigationStack {
            Form {
                descriptionSection
                ExerciseProgressSection(mastery: $mastery,
                                        lastPracticed: exercise.lastPracticed,
                                        trajectory: TempoTrajectory.reading(for: exercise.uid,
                                                                            in: sessionRecords),
                                        runCount: TempoTrajectory.runCount(for: exercise.uid,
                                                                           in: sessionRecords))
                linkedSongsSection
                feelSection
                templateSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.practice)
            .sheet(isPresented: $showingSongPicker) {
                LinkPickerSheet(
                    title: "Link songs",
                    prompt: "Search songs",
                    emptyCatalog: "No songs in your library yet.",
                    candidates: allSongs,
                    label: { $0.title.isEmpty ? "Untitled song" : $0.title },
                    subtitle: { $0.artist.isEmpty ? nil : $0.artist },
                    isLinked: { isLinked($0) },
                    toggle: { toggleLink($0) },
                    accent: PocketColor.practice)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitNotes(); commitMastery()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Template (read-only, ADR 0068)

    /// The exercise's template — set at creation and **immutable** (ADR 0068). Shown so the drill's
    /// type reads at a glance; not editable, because changing it would mean a different renderer and
    /// a different authoring surface (delete + recreate to change type).
    private var templateSection: some View {
        Section {
            HStack(spacing: 8) {
                Text("Template").foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                Label(exercise.template.displayName, systemImage: exercise.template.iconName)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
            }
        } footer: {
            Text("The kind of drill, set when it was created. It groups the exercise in your "
                 + "library and can't be changed.")
        }
    }

    // MARK: - Description (editable) + tags

    private var descriptionSection: some View {
        Section {
            TextField("Technique cues, target feel, where it's from…", text: $notes, axis: .vertical)
                .lineLimit(3...8)
                .keyboardDoneButton()
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
            Text("Description")
        } footer: {
            Text("A note to yourself about the drill — saved with the exercise.")
        }
    }

    // MARK: - Linked songs (ADR 0111)

    /// The songs this drill is **for** — the exercise side of the `Exercise.linkedSongs` ↔
    /// `Song.linkedExercises` edge. A reusable repertoire association (it outlives any routine);
    /// each row unlinks with a swipe, and **Link songs** opens the multi-select picker. Link
    /// changes persist immediately (a discrete add/remove, unlike the on-Done notes/mastery commit).
    private var linkedSongsSection: some View {
        Section {
            if exercise.linkedSongs.isEmpty {
                Text("Not linked to any songs yet — link the songs this drill helps you play.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                ForEach(linkedSongsByTitle, id: \.persistentModelID) { song in
                    HStack(spacing: 8) {
                        Text(song.title.isEmpty ? "Untitled song" : song.title)
                            .foregroundStyle(PocketColor.textPrimary)
                        if !song.artist.isEmpty {
                            Text(song.artist)
                                .font(.futura(.caption))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                    }
                }
                .onDelete(perform: unlinkSongs)
            }
            Button { showingSongPicker = true } label: {
                Label("Link songs", systemImage: "plus.circle")
                    .foregroundStyle(PocketColor.practice)
            }
        } header: {
            Text("Songs")
        } footer: {
            Text("The songs this drill is for. Links show on the song too, and later seed a "
                 + "one-tap practice routine for it.")
        }
    }

    private var linkedSongsByTitle: [Song] {
        exercise.linkedSongs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func isLinked(_ song: Song) -> Bool {
        exercise.linkedSongs.contains { $0.persistentModelID == song.persistentModelID }
    }

    /// Toggle a song's link from the picker — mutating the relationship persists it; `save()` makes
    /// it durable so the picker checkmark and the section behind it both reflect it live.
    private func toggleLink(_ song: Song) {
        if let index = exercise.linkedSongs.firstIndex(where: { $0.persistentModelID == song.persistentModelID }) {
            exercise.linkedSongs.remove(at: index)
        } else {
            exercise.linkedSongs.append(song)
        }
        try? modelContext.save()
    }

    private func unlinkSongs(at offsets: IndexSet) {
        let targets = offsets.map { linkedSongsByTitle[$0] }
        for song in targets {
            exercise.linkedSongs.removeAll { $0.persistentModelID == song.persistentModelID }
        }
        try? modelContext.save()
    }

    // MARK: - Meter & subdivision (read-only)

    /// Meter and **Rhythm** — one rhythm row, not two. The old "Subdivision" row is gone with the
    /// field behind it (ADR 0121): it never reached the metronome, so it stated a rhythm the drill
    /// didn't play. Rhythm is omitted when the drill states none — a chord-changing drill has no note
    /// density to report, and an absent row means "not stated", never a defaulted "quarters".
    private var feelSection: some View {
        Section {
            LabeledContent("Time signature") {
                Text(exercise.timeSignatureLabel).font(.pocketMono(.body))
            }
            if let noteRate = exercise.noteRate {
                LabeledContent("Rhythm") { Text(noteRate.label) }
            }
        } header: {
            Text("Feel")
        } footer: {
            Text("Rhythm is how many notes you play per beat — what the command tempo is measured "
                 + "in. Change it in Edit shape and you'll be asked what should happen to that tempo.")
        }
    }

    // MARK: - Helpers

    /// Persist an edited description, trimmed. A no-op when unchanged, so opening and closing the
    /// sheet without touching the field never writes to the store.
    private func commitNotes() {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != exercise.notes else { return }
        exercise.notes = trimmed
        try? modelContext.save()
    }

    /// Persist an edited mastery rating on Done, only when it differs from what's stored — a
    /// deliberate self-assessment (ADR 0070), never computed from playing.
    private func commitMastery() {
        guard mastery != exercise.mastery else { return }
        exercise.mastery = mastery
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
