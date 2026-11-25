import SwiftUI

/// The song's **Practise** section (ADR 0258): **Map the song**, the **Exercises** row, then **Build a
/// routine for this song**, split out of `SongDetailsSheet` to keep that file under the 400-line cap — the
/// same move `RoutineDetailView+References.swift` makes for the same reason. It was headed *Exercises for
/// this song*, with the map in a section of its own above it.
///
/// **The linked drills sit behind a row (ADR 0309 D3).** They were listed on the sheet, which is the list
/// that grows: a song worked on for months collects drills, and ADR 0258 moved everything that grows
/// behind a row that says what's inside. The row counts them, as Progress and References count theirs, and
/// opens `SongExercisesScreen`, which lists them and links more. Build a routine stays here: it's
/// something you do with the song, and it reads the linked drills either way.
extension SongDetailsSheet {

    /// The map, the exercises that **serve** this song, and the routine built from them.
    var practiseSection: some View {
        Section {
            mapRow
            exercisesRow
            buildRoutineButton
        } header: {
            Text("Practise")
        } footer: {
            Text("Build a routine strings your linked exercises together with your saved loops and a full "
                 + "play-through, ready to review and save.")
        }
    }

    private var exercisesRow: some View {
        NavigationLink { SongExercisesScreen(song: song) } label: {
            HubRow(icon: "metronome", title: "Exercises",
                   value: DetailSheetText.linkedExercises(song.linkedExercises.count))
        }
    }

    /// Whether "Build a routine" has anything to work with — a linked exercise or a saved loop
    /// (ADR 0111). Mirrors `SongRoutineBuilder.canBuild` so the button disables when the generated
    /// routine would be a lone play-through.
    var canBuildRoutine: Bool { SongRoutineBuilder.canBuild(for: song) }

    /// "Build a routine for this song" (ADR 0111) — materialises a real `Routine`. A song with
    /// nothing linked disables it.
    @ViewBuilder
    var buildRoutineButton: some View {
        Button {
            buildingRoutine = true
        } label: {
            Label("Build a routine for this song", systemImage: "wand.and.stars")
                .foregroundStyle(canBuildRoutine ? PocketColor.practice : PocketColor.textSecondary)
        }
        .disabled(!canBuildRoutine)
    }
}

/// **Song details › Exercises** (ADR 0309 D3): the song side of the `Song.linkedExercises` ↔
/// `Exercise.linkedSongs` edge (ADR 0111), as the exercise ⓘ's *Songs* screen is the other side. It hosts
/// **Link exercises** (the multi-select picker). Link changes persist immediately — a discrete, intentional
/// edit, as on the sheet it came from.
///
/// **A linked drill is a route, not a label (ADR 0172).** Tapping one opens its run screen, pushed in this
/// sheet's `NavigationStack` from here, so the back chevron returns here, then to the song. The push is
/// this screen's own: declared at the sheet's root instead, back from the run screen skipped this list and
/// landed on Song details (seen in `SongExercisesUITests`, 2026-11-21).
///
/// Every presentation this screen raises hangs off its own `Form` (ADR 0258 D3): a presentation raised
/// from a row inside a sheet's form dismisses the sheet instead.
struct SongExercisesScreen: View {
    let song: Song

    @Environment(\.modelContext) private var modelContext
    @State private var candidates: [Exercise] = []
    @State private var showingPicker = false
    /// The drill being opened. Bool-bound below, not `.navigationDestination(item:)`: a model's
    /// `persistentModelID` can flip on a save and item-based presentation reads that as an identity change
    /// and pops (ADR 0090).
    @State private var opening: Exercise?

    var body: some View {
        Form {
            Section {
                if song.linkedExercises.isEmpty {
                    Text("No drills linked yet.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    // Keyed by `uid`, not `persistentModelID`: these rows drive a presentation, and a
                    // model's `persistentModelID` can flip temporary→permanent on a save (ADR 0090).
                    ForEach(linkedByName, id: \.uid) { exercise in
                        row(exercise)
                    }
                    .onDelete(perform: unlink)
                }
                Button {
                    // Fetched on the tap that asks for the picker, not in the picker's own `.task` — a task
                    // would let the sheet draw its "No exercises in your library yet" empty state for a frame
                    // before the real list arrived.
                    candidates = LibraryPools.exercisesByName(in: modelContext)
                    showingPicker = true
                } label: {
                    Label("Link exercises", systemImage: "plus.circle")
                        .foregroundStyle(PocketColor.practice)
                }
            } footer: {
                Text("The exercises that help you play this song — they show on the exercise too. Tap one to "
                     + "run it.")
            }
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPicker) {
            LinkPickerSheet(
                title: "Link exercises",
                prompt: "Search exercises",
                emptyCatalog: "No exercises in your library yet.",
                candidates: candidates,
                label: { $0.name.isEmpty ? "Untitled exercise" : $0.name },
                subtitle: { $0.template.displayName },
                isLinked: { isLinked($0) },
                toggle: { toggle($0) },
                accent: PocketColor.practice)
        }
        .navigationDestination(isPresented: Binding(get: { opening != nil },
                                                    set: { if !$0 { opening = nil } })) {
            // Through `ExerciseRunScreen`, never `ExerciseRunView` — it is the one place that decides which
            // run screen a drill gets, so a freeform block gets its own (ADR 0136).
            if let exercise = opening { ExerciseRunScreen(exercise: exercise) }
        }
    }

    /// One linked drill. A `Button` with `.buttonStyle(.plain)` rather than a `NavigationLink`, for the
    /// reason `ReferenceLinkRow` states: a link inside a `List` row swallows the swipe actions, and
    /// swipe-to-unlink is the only way to break the link from here. The chevron carries the "this goes
    /// somewhere" reading a plain row can't.
    private func row(_ exercise: Exercise) -> some View {
        Button {
            opening = exercise
        } label: {
            HStack(spacing: 8) {
                Text(exercise.name.isEmpty ? "Untitled exercise" : exercise.name)
                    .foregroundStyle(PocketColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(exercise.template.displayName)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.futura(.caption2, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
                    .accessibilityHidden(true)
            }
            // The whole row is the target. A plain-style button in a list row answers only where it draws,
            // so a tap in the gap between the name and the chevron did nothing — the row's middle, where a
            // thumb or a UI test lands.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this drill's run screen")
    }

    private var linkedByName: [Exercise] {
        song.linkedExercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func isLinked(_ exercise: Exercise) -> Bool {
        song.linkedExercises.contains { $0.persistentModelID == exercise.persistentModelID }
    }

    /// Toggle a drill's link from the picker — mutating the relationship + `save()` keeps the picker's
    /// checkmark and the list behind it in sync.
    private func toggle(_ exercise: Exercise) {
        if let index = song.linkedExercises.firstIndex(where: {
            $0.persistentModelID == exercise.persistentModelID
        }) {
            song.linkedExercises.remove(at: index)
        } else {
            song.linkedExercises.append(exercise)
        }
        modelContext.saveOrLog()
    }

    private func unlink(at offsets: IndexSet) {
        let targets = offsets.map { linkedByName[$0] }
        for exercise in targets {
            song.linkedExercises.removeAll { $0.persistentModelID == exercise.persistentModelID }
        }
        modelContext.saveOrLog()
    }
}
