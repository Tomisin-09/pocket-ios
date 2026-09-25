import Foundation

/// **Beat 1, scripted** — the starter track only (ADR 0220 D3, D6).
///
/// A play-along tap does not snap (`tapAB()` sets A and B at the raw playhead), and a player tapping
/// Loop by ear lands 150–250 ms late, which on *Binta* cuts into the bar-9 kick. So on the one song
/// where we know where the good four bars are, playback **pauses at each marker** and the player's
/// Loop tap lands on it:
///
///     leadIn ──crosses Chords start──▶ heldAtStart ──Loop (A)──▶ awaitingEnd
///        ▲                                 │                         │
///        └──────── rewound past it ────────┘            crosses Solo start
///                                                                    ▼
///     finished ◀────────────── Loop (B): the span closes ──── heldAtEnd
///
/// **The pause is the app saying "here". The tap is still the player's**, on the button they will
/// use from then on — nothing advances on a Next (ADR 0149 §1). A span that closes anywhere, by any
/// route, finishes the script: beat 1 is done however it was done.
///
/// **This type decides; it does not act.** It is handed the playhead once per display frame by the
/// practice model — never by a view body, which ADR 0153 keeps off the playhead — and returns the
/// position to pause at. The model pauses and **seeks back onto that position exactly**: at 120 Hz a
/// frame can overshoot the marker by up to ~16 ms, which is the lateness this exists to remove.
///
/// The stops are `StarterTrack`'s **constants**, never the `Marker` records (D5). A player who renames
/// or deletes a marker before the walkthrough reaches it must not break it.
///
/// Pure and Foundation-only, so the whole cycle is unit-tested (AGENTS.md).
struct StarterTrackScript: Equatable {

    enum Stage: Equatable {
        /// Playing toward the first stop, no span yet.
        case leadIn
        /// Paused on the first stop, waiting for Loop.
        case heldAtStart
        /// A is down; playing toward the second stop.
        case awaitingEnd
        /// Paused on the second stop, waiting for Loop to close the span.
        case heldAtEnd
        /// The span closed. Nothing here pauses again.
        case finished
    }

    /// The A/B span as this script needs it: in song **seconds**, which is what the stops are in.
    enum Span: Equatable {
        case idle
        case armed(TimeInterval)
        case set
    }

    /// The longest jump between two frames that still counts as *playing through* a stop. A frame at
    /// 2× on a 60 Hz display covers ~33 ms of song, so half a second is generous for a hitch and far
    /// short of any deliberate seek — a scrub or a ten-second skip across a stop does not trip it.
    static let maxStride: TimeInterval = 0.5

    /// How far before the first stop the playhead must go before that stop re-arms. Clear of the
    /// sub-millisecond error a seek back onto the marker leaves (a frame-rounded `seekFrame`), so
    /// resuming from the marker never re-trips it.
    static let rewindSlack: TimeInterval = 0.1

    let start: TimeInterval
    let end: TimeInterval
    /// Where playback begins, so the section is heard arriving (D3 step 1).
    let leadIn: TimeInterval
    private(set) var stage: Stage = .leadIn

    init(start: TimeInterval = StarterTrack.chordsStart.seconds,
         end: TimeInterval = StarterTrack.soloStart.seconds,
         leadIn: TimeInterval = StarterTrack.leadInSeconds) {
        self.start = start
        self.end = end
        self.leadIn = leadIn
    }

    /// Whether the Loop button should carry the hint: the script is holding on a stop and waiting
    /// for the player's tap.
    var hintsLoop: Bool { stage == .heldAtStart || stage == .heldAtEnd }

    /// One display frame's worth of playback, from `previous` to `current` (song seconds). Returns
    /// the song time to pause **and seek** to when this frame played through a stop, else `nil`.
    mutating func tick(from previous: TimeInterval, to current: TimeInterval,
                       span: Span) -> TimeInterval? {
        spanChanged(span)
        switch stage {
        case .leadIn:
            guard span == .idle, Self.played(from: previous, to: current, through: start) else { return nil }
            stage = .heldAtStart
            return start
        case .heldAtStart:
            // Rewound to before the marker without tapping Loop: let it stop there again.
            if current < start - Self.rewindSlack { stage = .leadIn }
            return nil
        case .awaitingEnd:
            guard case .armed(let pointA) = span, pointA < end,
                  Self.played(from: previous, to: current, through: end) else { return nil }
            stage = .heldAtEnd
            return end
        case .heldAtEnd, .finished:
            return nil
        }
    }

    /// The span moved — a Loop tap, the strip's ✕, a hold-drag. Also folded into every `tick`, so the
    /// two can never disagree about which stop is live.
    mutating func spanChanged(_ span: Span) {
        switch (stage, span) {
        case (.finished, _):
            return
        case (_, .set):
            stage = .finished
        case (.leadIn, .armed), (.heldAtStart, .armed):
            stage = .awaitingEnd
        case (.awaitingEnd, .idle), (.heldAtEnd, .idle):
            // A cleared before B: start over from the first stop.
            stage = .leadIn
        default:
            return
        }
    }

    /// Whether continuous playback from `previous` to `current` reached `stop`. Strictly before on
    /// one side and at-or-past on the other, so a playhead sitting *on* the stop — where the seek-back
    /// left it — does not trip it a second time when play resumes.
    static func played(from previous: TimeInterval, to current: TimeInterval,
                       through stop: TimeInterval) -> Bool {
        previous < stop && current >= stop && current - previous <= maxStride
    }
}
