import Foundation

/// **The two hints** the starter track's first session carries beside the beats (ADR 0220 D4): the
/// in-song click, once beat 1's loop is playing, and the Backing track flag on the loop the player
/// kept, once the ceremony has closed.
///
/// A hint is not a beat, in three ways. **It never gates anything**: the beats move on whether or
/// not it is taken, and nothing here is read by `SongWalkthrough`. **It is shown once**: taken,
/// dismissed or replaced, it does not come back this run. And **it cannot make the ceremony
/// happen**, which stays on beat 3 (0149 §5).
///
/// **One at a time.** The backing-track hint replaces a click hint still showing: that one has had
/// two beats to be noticed, and two pointers on one screen is how guidance turns into a ride (0149
/// §5's warning, which the amendment answered by cutting five steps to three).
///
/// **Starter track only** (D6). Only there is the click known to run from the first note (D1) and
/// the loop known to be four bars of chords — the claim the backing-track hint makes. So that hint
/// is offered only when the loop kept is the scripted span; a player who looped something else by
/// hand is not told it makes a good bed.
///
/// Pure and Foundation-only, so every rule here is unit-tested (AGENTS.md). The model reports what
/// happened; the view reads `showing`.
struct StarterTrackHints: Equatable {

    enum Hint: Equatable {
        /// The metronome in the speed bar.
        case click
        /// The Backing track toggle on the loop just kept.
        case backingTrack
    }

    /// The in-song click as the model sees it when a loop starts playing.
    enum Click: Equatable {
        /// No grid to click against: the player has cleared the song's tempo. The hint points at a
        /// click that exists, never at a tempo to set — that is the skill D1 says a new player lacks.
        case unavailable
        case off
        case running
    }

    /// How far the kept loop's edges may sit from the two bar lines and still be the scripted span.
    /// The script seeks the playhead *onto* each stop, so a scripted loop lands within a millisecond;
    /// a handle released onto a marker snaps there exactly (ADR 0021). A tap by ear lands 150–250 ms
    /// late (D3), which this rejects.
    static let spanTolerance: TimeInterval = 0.05

    /// The hint on screen, if any.
    private(set) var showing: Hint?
    /// Hints that have had their turn. Nothing leaves this set (D4: shown once).
    private(set) var spent: Set<Hint> = []
    /// The loop the backing-track hint points at: the one kept on the scripted span.
    private(set) var keptLoopID: UUID?

    /// A loop began playing: beat 1's span closed, and the four bars are going round.
    mutating func loopStarted(click: Click) {
        switch click {
        case .off: offer(.click)
        case .running: retire(.click)       // already found; there is nothing to point at
        case .unavailable: break            // stays eligible, and says nothing
        }
    }

    /// The click was turned on — from the hint or not, the player has found it.
    mutating func clickTurnedOn() { retire(.click) }

    /// A loop was saved. The backing-track hint is offered when it is the scripted four bars.
    mutating func loopKept(id: UUID, start: TimeInterval, end: TimeInterval) {
        guard Self.isScriptedSpan(start: start, end: end), !spent.contains(.backingTrack) else { return }
        keptLoopID = id
        offer(.backingTrack)
    }

    /// The kept loop is now a backing track: the toggle was switched on and the edit saved.
    mutating func backingTrackUsed() { retire(.backingTrack) }

    /// The kept loop was deleted: the hint would point at a row that is not there.
    mutating func keptLoopRemoved() { retire(.backingTrack) }

    /// The hint's own ✕.
    mutating func dismiss() {
        if let showing { retire(showing) }
    }

    /// Whether a loop is the one the script closes: *Chords start* to *Solo start* (D2, D3).
    static func isScriptedSpan(start: TimeInterval, end: TimeInterval) -> Bool {
        abs(start - StarterTrack.chordsStart.seconds) <= spanTolerance
            && abs(end - StarterTrack.soloStart.seconds) <= spanTolerance
    }

    private mutating func offer(_ hint: Hint) {
        guard !spent.contains(hint), showing != hint else { return }
        if let showing { spent.insert(showing) }     // one at a time: the newer one replaces it
        showing = hint
    }

    private mutating func retire(_ hint: Hint) {
        spent.insert(hint)
        if showing == hint { showing = nil }
    }
}
