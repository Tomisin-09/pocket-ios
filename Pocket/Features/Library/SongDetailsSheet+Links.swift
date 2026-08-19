import SwiftUI

/// The song's **Exercises for this song** section (ADR 0111), split out of `SongDetailsSheet` to
/// keep that file under the 400-line cap — the same move `RoutineDetailView+References.swift` makes
/// for the same reason.
///
/// The section shows the song side of the `Song.linkedExercises` ↔ `Exercise.linkedSongs` edge, and
/// hosts the two actions that act on it: **Link exercises** (the multi-select picker) and **Build a
/// routine for this song** (the generator). Link changes persist immediately, matching the inline
/// notes save on this sheet — a discrete, intentional edit, unlike the staged metadata form behind
/// **Edit**.
///
/// **A linked drill is a route, not a label (ADR 0172).** The rows used to be inert `Text`: the app
/// knew this exercise was *for* this song, said so, and then made you go and find it in the
/// exercise library. Tapping one now opens its run screen.
extension SongDetailsSheet {

    /// The exercises that **serve** this song. Each row opens its run screen; each unlinks with a
    /// swipe.
    var linkedExercisesSection: some View {
        Section {
            if song.linkedExercises.isEmpty {
                Text("No drills linked yet — link the exercises that help you play this song.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                // Keyed by `uid`, not `persistentModelID`: these rows now drive a presentation, and
                // a model's `persistentModelID` can flip temporary→permanent on a save (ADR 0090).
                ForEach(linkedExercisesByName, id: \.uid) { exercise in
                    linkedExerciseRow(exercise)
                }
                .onDelete(perform: unlinkExercises)
            }
            Button {
                // Fetched on the tap that asks for the picker, not in the picker's own `.task` —
                // a task would let the sheet draw its "No exercises in your library yet" empty
                // state for a frame before the real list arrived.
                exerciseCandidates = LibraryPools.exercisesByName(in: modelContext)
                showingExercisePicker = true
            } label: {
                Label("Link exercises", systemImage: "plus.circle")
                    .foregroundStyle(PocketColor.practice)
            }
            buildRoutineButton
        } header: {
            Text("Exercises for this song")
        } footer: {
            Text("Exercises that help you play this song — they show on the exercise too. "
                 + "Tap one to run it. Build a routine strings these together with your saved "
                 + "loops and a full play-through, ready to review and save.")
        }
    }

    /// One linked drill. A `Button` with `.buttonStyle(.plain)` rather than a `NavigationLink`, for
    /// the reason `ReferenceLinkRow` states: a link inside a `List` row swallows the swipe actions,
    /// and swipe-to-unlink is the only way to break the link from here. The chevron carries the
    /// "this goes somewhere" reading a plain row can't.
    private func linkedExerciseRow(_ exercise: Exercise) -> some View {
        Button {
            openingExercise = exercise
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
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this drill's run screen")
    }

    var linkedExercisesByName: [Exercise] {
        song.linkedExercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Whether "Build a routine" has anything to work with — a linked exercise or a saved loop
    /// (ADR 0111). Mirrors `SongRoutineBuilder.canBuild` so the button disables when the generated
    /// routine would be a lone play-through.
    var canBuildRoutine: Bool { SongRoutineBuilder.canBuild(for: song) }

    /// "Build a routine for this song" (ADR 0111) — a **Pro** action, since it materialises a real
    /// `Routine` (ADR 0112). A free player keeps the row tappable so it can open the paywall; only a
    /// song with nothing linked disables it.
    @ViewBuilder
    var buildRoutineButton: some View {
        Button {
            guard AccessPolicy.canAuthorRoutine(isPro: isPro) else {
                return presentPaywall(.routine(.generate))
            }
            buildingRoutine = true
        } label: {
            Label("Build a routine for this song",
                  systemImage: isPro ? "wand.and.stars" : "lock.fill")
                .foregroundStyle(canBuildRoutine ? PocketColor.practice : PocketColor.textSecondary)
        }
        .disabled(isPro && !canBuildRoutine)
    }

    func isLinked(_ exercise: Exercise) -> Bool {
        song.linkedExercises.contains { $0.persistentModelID == exercise.persistentModelID }
    }

    /// Toggle a drill's link from the picker — mutating the relationship + `save()` keeps the picker
    /// checkmark and the section behind it in sync.
    func toggleLink(_ exercise: Exercise) {
        if let index = song.linkedExercises.firstIndex(where: {
            $0.persistentModelID == exercise.persistentModelID
        }) {
            song.linkedExercises.remove(at: index)
        } else {
            song.linkedExercises.append(exercise)
        }
        try? modelContext.save()
    }

    func unlinkExercises(at offsets: IndexSet) {
        let targets = offsets.map { linkedExercisesByName[$0] }
        for exercise in targets {
            song.linkedExercises.removeAll { $0.persistentModelID == exercise.persistentModelID }
        }
        try? modelContext.save()
    }
}
