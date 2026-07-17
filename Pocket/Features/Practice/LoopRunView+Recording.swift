import SwiftUI

/// Loop-trainer take lifecycle (ADR 0069) — the owner-specific glue around the shared, owner-agnostic
/// record controls (`RecordControls.swift`). The arm toggle, setup hint, and live status are those
/// shared views; here we bind the take to *this loop* on finalize and delete.
extension LoopRunView {

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
