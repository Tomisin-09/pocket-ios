import SwiftUI

/// The Exercises library's **hold menu** — a drill's own actions, above the Favourite and Delete the
/// shared modifier adds (`.pocketRowActions`, Slice 3).
///
/// Split out when *Add to routine…* (ADR 0222) took the view past the 400-line cap, along the seam
/// `+Folders` already cut: what stays in `ExerciseLibraryView` decides which drills are on screen;
/// this decides what you can do to one of them. Internal members only because a same-module
/// extension cannot see `private`.
extension ExerciseLibraryView {

    /// The drill's own long-press actions: read what it is, file it, put it in a routine, or fork it.
    func menuItems(for exercise: Exercise) -> [PocketRowMenuItem] {
        [PocketRowMenuItem("Details", systemImage: "info.circle") { detailExercise = exercise },
         // "Add to folder…", never "Move to" (ADR 0210 D1) — a drill in two folders is the feature.
         PocketRowMenuItem("Add to folder…", systemImage: "folder.badge.plus") { filing = exercise },
         PocketRowMenuItem("Add to routine…", systemImage: "text.badge.plus") { addToRoutine(exercise) },
         PocketRowMenuItem("Duplicate", systemImage: "plus.square.on.square") { duplicate(exercise) }]
    }

    /// Open the add-to-routine sheet for a drill (ADR 0222). Adding a block **is** editing a routine,
    /// so it takes the editor's own gate (`canAddRoutineUnits`) and the editor's paywall reason —
    /// the row is a second door into the same act, not a way round its wall.
    ///
    /// Not gated on `canRun`: a routine holding a drill its owner can't run yet is the same state the
    /// editor's picker already allows, and the player skips nothing it can't open.
    private func addToRoutine(_ exercise: Exercise) {
        guard AccessPolicy.canAddRoutineUnits(isPro: isPro) else {
            return presentPaywall(.routine(.edit))
        }
        routineRequest = .exercise(exercise, named: displayName(exercise))
    }

    /// Fork a drill into an editable copy — the cheapest way to make a variant of a template you've
    /// already tuned (Slice 3). Copying is **authoring**, so it takes the same `canAuthor` gate as
    /// creation (ADR 0112): a free player can run the seeded Pro-template freebies but can't fork
    /// one into a drill of their own. The copy is inserted before its song links are assigned —
    /// a relationship can't be set on an un-inserted model.
    private func duplicate(_ exercise: Exercise) {
        guard AccessPolicy.canAuthor(exercise.template, isPro: isPro) else {
            return presentPaywall(.newExercise(exercise.template))
        }
        let name = CopyNaming.copyName(of: exercise.name, existing: exercises.map(\.name))
        let copy = exercise.duplicated(named: name)
        context.insert(copy)
        copy.linkedSongs = exercise.linkedSongs
        haptic(.medium)
    }
}
