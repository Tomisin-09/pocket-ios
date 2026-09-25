import Foundation

// MARK: - The starter track's two hints (ADR 0220 D4)
//
// The click, once beat 1's loop is playing, and the Backing track flag on the loop the player kept,
// once the ceremony has closed. The rules are the pure `StarterTrackHints`; this file reports what
// the player did and says what to draw. `starterHints` is `nil` on every song but the starter track
// (D6), so every hook here no-ops on almost every visit.

extension WaveformPracticeModel {

    /// The hint to draw now. None while the ceremony has the card: that moment is the player's, and a
    /// pointer pulsing somewhere else would talk over it (0149 §5).
    var walkthroughHint: StarterTrackHints.Hint? {
        guard walkthrough?.phase != .ceremony else { return nil }
        return starterHints?.showing
    }

    /// Whether the speed bar's metronome carries the ring.
    var walkthroughHintsMetronome: Bool { walkthroughHint == .click }

    /// The loop row that carries the ring, if any: the one kept on the scripted span.
    var walkthroughHintedLoopID: UUID? {
        walkthroughHint == .backingTrack ? starterHints?.keptLoopID : nil
    }

    /// The kept loop's name as it reads now — the player may have renamed it already.
    var walkthroughHintedLoopName: String {
        loops.first { $0.uid == starterHints?.keptLoopID }?.name ?? "the loop"
    }

    /// The hint's own ✕. The beats carry on; the guide's ✕ is the one that ends everything.
    func dismissWalkthroughHint() {
        advanceHints { $0.dismiss() }
    }

    // MARK: Hooks

    /// A span closed and is looping (`walkthroughSpanDidChange`).
    func walkthroughLoopStarted() {
        let click: StarterTrackHints.Click = metronomeOn ? .running : (canUseMetronome ? .off : .unavailable)
        advanceHints { $0.loopStarted(click: click) }
    }

    /// The click was switched on (`toggleMetronome`).
    func walkthroughClickTurnedOn() {
        advanceHints { $0.clickTurnedOn() }
    }

    /// A loop was saved (`createLoop`), in song seconds.
    func walkthroughLoopKept(_ id: UUID, start: TimeInterval, end: TimeInterval) {
        advanceHints { $0.loopKept(id: id, start: start, end: end) }
        // A ring on a row inside a folded panel points at nothing.
        if starterHints?.showing == .backingTrack { loopsExpanded = true }
    }

    /// Edit loop closed. Its toggle writes the flag only on Done (Cancel discards it), so the loop is
    /// read after the sheet has gone rather than the toggle watched inside it.
    func walkthroughLoopEditClosed() {
        guard let id = starterHints?.keptLoopID,
              loops.first(where: { $0.uid == id })?.isBackingTrack == true else { return }
        advanceHints { $0.backingTrackUsed() }
    }

    /// Loops were deleted. At the delete rather than its commit: the row hides straight away.
    func walkthroughLoopsDeleted(_ uids: Set<UUID>) {
        guard let id = starterHints?.keptLoopID, uids.contains(id) else { return }
        advanceHints { $0.keptLoopRemoved() }
    }

    /// Mutate the hints, writing them back only on a change, and end the walkthrough if that was
    /// the last thing it was showing.
    private func advanceHints(_ change: (inout StarterTrackHints) -> Void) {
        guard var hints = starterHints else { return }
        change(&hints)
        guard hints != starterHints else { return }
        starterHints = hints
        endWalkthroughIfDone()
    }
}
