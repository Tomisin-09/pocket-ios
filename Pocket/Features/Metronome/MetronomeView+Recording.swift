import SwiftData
import SwiftUI

/// The metronome's take lifecycle (ADR 0287) — the owner-specific glue around the shared record
/// controls, as `ExerciseRunView+Recording` is for an exercise. A take here is the microphone only
/// (ADR 0069 D1): through the speaker the mic hears the click, which is wanted; through headphones the
/// take is just the playing.
extension MetronomeView {

    /// Start the click by `start` — the transport's Start or the automator's **Start ramp** — with an
    /// armed take begun **first**. `beginArmedTake()` flips the session to record before anything
    /// sounds; once the click is running, the flip would happen under it, which is the glitch ADR
    /// 0069's arm grammar exists to avoid. So both ways in come through here, and
    /// `.onChange(of: engine.transport)` would be too late.
    ///
    /// The click is snapshotted **after** `start`, so the withdrawal is the tier actually in force: a
    /// ramp plays a full click whatever is configured (ADR 0132 §4).
    ///
    /// Only an armed recorder begins a take, and the arm is offered only while stopped, so a ramp
    /// started over a running take leaves the take, and its snapshot, alone.
    func startClick(_ start: () -> Void) {
        let beginsTake = recorder.isArmed
        recorder.beginArmedTake()
        start()
        if beginsTake, recorder.isRecording { takeSitting = engine.journalContext }
    }

    /// Save a rolling take against the metronome, with the click it began on. Idempotent: the Stop
    /// button, leaving the screen, and leaving the app can all reach it.
    func finishTake() {
        guard recorder.isRecording else { return }
        recorder.finishIfRecording(owner: .metronome(takeSitting ?? engine.journalContext),
                                   context: modelContext)
        takeSitting = nil
    }

    /// Delete a take from the Takes list — the file and the row (ADR 0069 retention).
    func deleteTake(_ take: Recording) {
        try? RecordingStore.delete(fileName: take.fileName)
        modelContext.delete(take)
        try? modelContext.save()
    }
}

/// *Take saved*, then *3 takes on the metronome ›* — the way back to what was recorded here.
///
/// Its own view, holding its own query, so the metronome's body (which re-renders on every tempo
/// change) never filters the takes.
struct MetronomeTakesLine: View {
    var recorder: RecordingController
    var onOpenTakes: () -> Void

    @Query(sort: \Recording.createdAt, order: .reverse) private var takes: [Recording]

    var body: some View {
        TakeSavedNote(recorder: recorder, takeCount: Recording.metronomeTakes(in: takes).count,
                      place: "on the metronome", onOpenTakes: onOpenTakes)
    }
}
