import Foundation

/// Pure, UI-free **promote** math (ADR 0079): after a training run summits the reach, promotion
/// moves `command` up to that reach. The two questions this answers — *should we offer the promote?*
/// and *what command does accepting produce?* — are the kind of boundary logic that breaks silently,
/// so they live here, engine- and SwiftUI-free, and are exhaustively unit-tested per AGENTS.md.
///
/// This is the same promotion the in-setup button and the routine Done screen apply; centralising it
/// means the standalone post-run offer, the routine toggle, and any future caller share one rule.
enum PromoteOffer {

    /// Whether there's anything to promote — a promotable reach strictly above the current command.
    /// Gated on the **ceiling-clamped** reach so a reach past the device ceiling with command already
    /// at the ceiling (e.g. command 300, auto-reach 315) reads as "nothing to promote" rather than
    /// offering a no-op. The completion surface omits the row when this is false (ADR 0079 §5). The
    /// "run completed" half of the trigger is the caller's (natural completion); this is the value half.
    static func canPromote(reach: Int, command: Int, ceiling: Int) -> Bool {
        promotedCommand(reach: reach, ceiling: ceiling) > command
    }

    /// The command a **default** promote produces: move up to the reach, but never past the device
    /// BPM `ceiling`. It's also the default the editable custom-value control (ADR 0079, follow-up)
    /// starts on. The reach then re-derives a bit above the new command (`TempoStretch`), and a pinned
    /// reach that command has caught up to is cleared by the model's `promoteCommand` — this function
    /// only computes the target command.
    static func promotedCommand(reach: Int, ceiling: Int) -> Int {
        min(ceiling, reach)
    }
}
