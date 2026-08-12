import Foundation

/// **What a note written here is about** (ADR 0160) — the engine's half of the metronome journal.
///
/// One computed property in its own file, like `+Withdrawal` and `+Automator`: the core file sits at
/// its 400-line ceiling, and this is one concern. Everything the context holds is a value the engine
/// already publishes, so the snapshot is a read and nothing more — no state, no side effect on the
/// click, which is what lets the composer open mid-run without touching the transport (ADR 0142).
extension StandaloneMetronomeEngine {

    /// The sitting as it stands **right now**, for `QuickJournalSheet(owner: .metronome(…))`.
    ///
    /// Read at the moment the composer opens and pinned there (ADR 0160 §5) — never rebuilt inside a
    /// sheet's content closure, which re-runs on every body pass and would record whichever tempo the
    /// last re-render happened to see.
    ///
    /// The withdrawal is `activeWithdrawal`, the tier **in force** with ADR 0132 §4's exclusions
    /// applied, not the stored preference: during a ramp the click is full, and a note claiming a
    /// withdrawal the player never heard is exactly the false context the journal exists to avoid.
    var journalContext: MetronomeJournalContext {
        MetronomeJournalContext(bpm: bpm, timeSignature: timeSignature,
                                subdivision: subdivision, withdrawal: activeWithdrawal)
    }
}
