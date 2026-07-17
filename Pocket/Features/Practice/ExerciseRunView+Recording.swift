import SwiftUI

/// Exercise-run take lifecycle (ADR 0069) — the owner-specific glue around the shared, owner-agnostic
/// record controls (`RecordControls.swift`), mirroring `LoopRunView+Recording`. Binds the take to
/// *this exercise* on finalize and delete.
extension ExerciseRunView {

    /// Finalize an in-flight take when the run ends or the screen exits, so a take is never left
    /// recording after the metronome it was played over has stopped. Idempotent.
    func finishTakeIfNeeded() {
        recorder.finishIfRecording(owner: .exercise(exercise), context: modelContext)
    }

    /// Delete a take from the Takes sheet — remove the file and the model row (ADR 0069 retention).
    func deleteTake(_ take: Recording) {
        try? RecordingStore.delete(fileName: take.fileName)
        modelContext.delete(take)
        try? modelContext.save()
    }
}
