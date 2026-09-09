import Foundation

/// Turning snags into a tighter loop (ADR 0200) — pure, SwiftData-free, and the thing that makes a
/// snag worth marking *today* rather than only once the Oracle can read one.
///
/// Three taps in the same bar are the app being told where the loop should actually be. The answer
/// is arithmetic on the marks, not a model call: take what they span, pad it, and offer it.
///
/// This composes with ADR 0199. A cluster is typically well under a second wide, and a loop that
/// tight was **impossible** before that ADR — the old floor was 2% of the song, so 4.8s on a
/// four-minute track. One change made the span expressible; this one says where it goes.
enum SnagCluster {

    /// Breathing room either side of the outermost marks. A snag lands *at* the moment it went
    /// wrong, which is already slightly after the move that caused it, so a loop pinned exactly to
    /// the marks would start too late to play into the problem.
    static let padSeconds: TimeInterval = 0.25

    /// How much of the loop the marks may span before tightening stops being worth offering.
    ///
    /// Snags spread evenly across a loop are a **true reading** — the trouble is not in one place —
    /// and the honest response is to offer nothing rather than pick an arbitrary cluster out of
    /// noise. A suggestion that fires on scattered marks would be wrong more often than right, and
    /// wrong here means moving a loop the player deliberately set.
    static let scatterRatio = 0.6

    /// A tighter span for the armed loop, in seconds, or `nil` when there is nothing worth
    /// proposing — no marks inside the loop, marks too scattered to point anywhere, or a proposal
    /// that would not actually be tighter than what is already there.
    ///
    /// A **single** snag is enough: one mark is a point rather than a span, and the floor-width
    /// window around it is exactly the "loop the moment it goes wrong" the player asked for by
    /// tapping. The result is clamped inside the current loop — this tightens, it never moves the
    /// loop somewhere new, because the player chose where it sits.
    static func proposal(snagSeconds: [TimeInterval],
                         loopStart: TimeInterval,
                         loopEnd: TimeInterval,
                         minSeconds: TimeInterval = WaveformGesture.minLoopSeconds)
        -> (start: TimeInterval, end: TimeInterval)? {

        let loopWidth = loopEnd - loopStart
        guard loopWidth > 0 else { return nil }

        let inside = snagSeconds.filter { $0 >= loopStart && $0 <= loopEnd }
        guard let lowest = inside.min(), let highest = inside.max() else { return nil }

        guard highest - lowest < loopWidth * scatterRatio else { return nil }

        var start = lowest - padSeconds
        var end = highest + padSeconds

        // Grow to the floor around the midpoint, so a single mark still yields a playable loop.
        if end - start < minSeconds {
            let mid = (start + end) / 2
            start = mid - minSeconds / 2
            end = mid + minSeconds / 2
        }

        // Stay inside the loop the player set, keeping the width if an edge is hit.
        if start < loopStart {
            end = Swift.min(loopEnd, end + (loopStart - start))
            start = loopStart
        }
        if end > loopEnd {
            start = Swift.max(loopStart, start - (end - loopEnd))
            end = loopEnd
        }

        // Nothing to offer if the "tighter" loop is the loop.
        guard end - start < loopWidth - 0.01 else { return nil }
        return (start, end)
    }
}
