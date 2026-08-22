import SwiftUI

/// Loop-trainer take lifecycle (ADR 0069) — the owner-specific glue around the shared, owner-agnostic
/// record controls (`RecordControls.swift`). The arm toggle, setup hint, and live status are those
/// shared views; here we bind the take to *this loop* on finalize and delete.
extension LoopRunView {

    /// Arm the recorder when this block was marked to record (ADR 0179), so the take begins with the
    /// run through the `beginArmedTake()` already sitting in `commitAndStart`.
    ///
    /// Called from `.onAppear`, which runs **before** the `.task` that reaches `maybeAutoStart()` —
    /// and that ordering is the whole thing. With auto-start on (the default) the block runs straight
    /// into `commitAndStart`, whose `beginArmedTake()` is a no-op on an unarmed controller: arm late
    /// and the block plays perfectly while recording nothing, with no error to show for it.
    ///
    /// `armIfPermitted()` never prompts — a routine cannot wait on a permission dialog, so the prompt
    /// happened when the block was marked, in the routine editor.
    func armIfBlockRecords() {
        guard routineContext?.recordsTake == true else { return }
        recorder.armIfPermitted()
    }

    /// Finalize an in-flight take when the run ends or the screen exits, so a take is never left
    /// recording after the audio it was played over has stopped. Idempotent.
    func finishTakeIfNeeded() {
        recorder.finishIfRecording(owner: .loop(loop), context: modelContext)
    }

    /// Delete a take from the Takes sheet — remove the file and the model row (ADR 0069 retention).
    func deleteTake(_ take: Recording) {
        try? RecordingStore.delete(fileName: take.fileName)
        modelContext.delete(take)
        try? modelContext.save()
    }
}
