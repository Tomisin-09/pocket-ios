import SwiftUI

/// Exercise-run take lifecycle (ADR 0069) — the owner-specific glue around the shared, owner-agnostic
/// record controls (`RecordControls.swift`), mirroring `LoopRunView+Recording`. Binds the take to
/// *this exercise* on finalize and delete.
extension ExerciseRunView {

    /// Arm the recorder when this block was marked to record (ADR 0179), so the take begins with the
    /// run through the `beginArmedTake()` already sitting in `commitAndStart`. Twin of
    /// `LoopRunView.armIfBlockRecords()`.
    ///
    /// Called from `.onAppear` **before** `maybeAutoStart()`, and that ordering is the whole thing.
    /// With auto-start on (the default) the block runs straight into `commitAndStart`, whose
    /// `beginArmedTake()` is a no-op on an unarmed controller: arm late and the block plays perfectly
    /// while recording nothing, with no error to show for it.
    ///
    /// `armIfPermitted()` never prompts — a routine cannot wait on a permission dialog, so the prompt
    /// happened when the block was marked, in the routine editor.
    func armIfBlockRecords() {
        guard routineContext?.recordsTake == true else { return }
        recorder.armIfPermitted()
    }

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
