import SwiftUI

/// **Receive an exercise** (ADR 0209 D4) — the in-app door on the Exercises library, and the twin of
/// `RoutineLibraryView+Receive`.
///
/// Split into its own file to keep `ExerciseLibraryView.swift` under the 400-line cap, the same way
/// `ExerciseDetailSheet+Share.swift` holds the sending control for the same reason.
///
/// The first door is tap-to-open, which is the one a teacher actually uses: they send a file, the
/// player taps it. This one exists because the file does not always arrive as a tap — it can be
/// sitting in Files, in iCloud Drive, or in a folder the player saved it to a week ago — and "you had
/// to open it from the message it came in" is a door that closes behind you. It does no work of its
/// own: it picks a URL and hands it to the same `PracticeReceiveHost` the tap goes through.
extension ExerciseLibraryView {

    /// The menu row, in the shared list-options menu.
    ///
    /// On the options menu rather than the nav bar, per ADR 0126: nothing on a nav bar may vary in
    /// width, and this is a labelled secondary action — a bare glyph for "open a file somebody sent
    /// you" would be unreadable.
    @ViewBuilder
    var receiveExerciseButton: some View {
        Button {
            importingExercise = true
            haptic(.light)
        } label: {
            Label("Receive an exercise…", systemImage: "square.and.arrow.down")
        }
    }
}
