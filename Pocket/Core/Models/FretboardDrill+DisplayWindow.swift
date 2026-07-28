import Foundation

// `FretboardDrill`'s **following viewport** (ADR 0083 S5) — split out of the model file to keep it
// under the length ceiling. Pure and Foundation-only, like the rest of the drill's math: it derives
// which slice of the neck the board should show from the notes themselves, so nothing about the
// window is persisted.

// MARK: - Display window (pure — derived from the notes, so the payload stays lean)

/// The visible slice of neck the board draws: `lowestFret` is the leftmost fret **column**, `span`
/// the number of columns. A plain value so the following-viewport math (ADR 0083 S5) stays pure and
/// unit-testable, and both the model and the renderer read the same window.
struct FretWindow: Equatable {
    var lowestFret: Int
    var span: Int
}

extension FretboardDrill {
    /// The widest a run stays legible without following (ADR 0083 S5), and the width of the following
    /// window itself. A drill whose fretted span fits in this many columns keeps the static full
    /// window — a gentle climb (e.g. a +1-per-pass warm-up living inside ~7 frets) never scrolls; only
    /// a genuine neck-climb wider than this follows the hand while it walks.
    static let comfortableFretSpan = 8
    /// How close (in frets) the active note may get to a window edge before the window scrolls to keep
    /// it in view (ADR 0083 S5). The window holds completely still until this margin is breached, so it
    /// never moves while the note is comfortably mid-board — the "only scroll when you have to" rule.
    static let followEdgeMargin = 1
    /// How many frets of already-played neck the following window keeps **behind** the active note when
    /// it scrolls (ADR 0083 S5) — kept deliberately small: a climbing hand reads the frets *ahead*, so
    /// after a scroll the note sits near the trailing edge and most of the window is the runway to come.
    /// Fewer trailing frets ⇒ more look-ahead ⇒ the note travels further before the next scroll, so the
    /// board reframes less often. Nonzero so a sliver of context survives the reframe.
    static let followTrailing = 1

    /// The fretted (non-open) fret numbers the drill actually uses.
    private var frettedNumbers: [Int] { notes.compactMap { $0?.fret }.filter { $0 > 0 } }

    /// Whether any slot is an **open string** (fret 0) — common on bass, where the flagship box is rooted
    /// on an open E/A/D/G (ADR 0116 S5).
    private var hasOpenNotes: Bool { notes.contains { $0?.fret == 0 } }

    /// The lowest fret **column** the board shows — the lowest fretted note, at least 1. When the drill
    /// also uses **open strings**, the window is framed from the nut (fret 1) so the open root reads
    /// contiguously with the low frets instead of stranded on the nut with a gap (ADR 0116 S5) — a bass
    /// box rooted on the open E is the motivating case, and open-position guitar boxes read better too.
    var displayLowestFret: Int {
        guard let low = frettedNumbers.min() else { return 1 }
        return hasOpenNotes ? 1 : max(1, low)
    }

    /// How many fret **columns** the board shows — enough to reach the highest fretted note, but at
    /// least a comfortable four so a two-fret drill isn't a cramped sliver.
    var displayFretSpan: Int {
        guard let high = frettedNumbers.max() else { return 4 }
        return max(4, high - displayLowestFret + 1)
    }

    /// The visible neck window given the currently-active note (ADR 0083 S5 — the following viewport).
    ///
    /// **At rest / animate-off (`activeIndex == nil`), or a run that already fits `comfortableFretSpan`,
    /// keep today's static full window** — the whole shape reads as a reference diagram, and a gentle
    /// climb that lives inside a comfortable board never scrolls at all. **Only a genuine neck-climb
    /// wider than that, while it walks,** follows the hand — and it follows by the *"only scroll when
    /// you have to"* rule: the window holds completely still until the active note comes within
    /// `followEdgeMargin` of an edge, then scrolls just enough to bring it back with `followLead` frets
    /// of runway ahead and the rest of the window as already-played history. It therefore never moves
    /// while the note is comfortably mid-board (the confusing case an earlier paged version produced).
    ///
    /// The window has memory (where it scrolled to last frame), but the whole thing stays a pure
    /// `fn(activeIndex)`: the walk is deterministic, so the window is recovered by folding the scroll
    /// rule over the notes from the start of the cycle up to the active one — no view state, still
    /// exhaustively unit-tested (S6), and the loop wrap (top of the climb → back to the bottom) falls
    /// out for free because the fold restarts at note 0.
    func displayWindow(activeIndex: Int?) -> FretWindow {
        let staticLow = displayLowestFret
        let staticSpan = displayFretSpan
        guard let activeIndex, noteCount > 0, staticSpan > Self.comfortableFretSpan else {
            return FretWindow(lowestFret: staticLow, span: staticSpan)
        }
        let width = Self.comfortableFretSpan
        let staticHigh = staticLow + staticSpan - 1
        let maxLow = max(staticLow, staticHigh - width + 1)   // never scroll past the run's own content
        let target = ((activeIndex % noteCount) + noteCount) % noteCount
        var low = staticLow                                   // the window starts anchored at the bottom
        for index in 0...target {
            let fret = followedFret(activeIndex: index) ?? low
            low = scrolled(low: low, toShow: fret, width: width, minLow: staticLow, maxLow: maxLow)
        }
        return FretWindow(lowestFret: low, span: width)
    }

    /// The scroll rule (ADR 0083 S5): keep the window put unless `fret` is within `followEdgeMargin` of
    /// an edge, in which case scroll so the note lands `followTrailing` frets in from the edge it is
    /// *leaving* — a little history behind, the rest of the window the runway it is heading into (so it
    /// travels far before scrolling again). Pure and total, clamped to `[minLow, maxLow]`.
    private func scrolled(low: Int, toShow fret: Int, width: Int, minLow: Int, maxLow: Int) -> Int {
        let high = low + width - 1
        if fret > high - Self.followEdgeMargin {           // climbing → reached the right edge; scroll up
            return min(maxLow, fret - Self.followTrailing)
        }
        if fret < low + Self.followEdgeMargin {            // descending → reached the left edge; scroll down
            return max(minLow, fret - (width - 1 - Self.followTrailing))
        }
        return low                                         // comfortably in view → hold
    }

    /// The fret the following window tracks: the active note's own fret when it is fretted, else the
    /// nearest fretted note on either side (so a rest or open string doesn't jerk the window). `nil`
    /// only when the drill has no fretted note at all.
    private func followedFret(activeIndex: Int) -> Int? {
        guard noteCount > 0 else { return nil }
        if let active = note(at: activeIndex), active.fret > 0 { return active.fret }
        for offset in 1...noteCount {
            if let back = note(at: activeIndex - offset), back.fret > 0 { return back.fret }
            if let forward = note(at: activeIndex + offset), forward.fret > 0 { return forward.fret }
        }
        return nil
    }
}
