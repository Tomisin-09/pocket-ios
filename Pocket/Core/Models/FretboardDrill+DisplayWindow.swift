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

    /// Whether the board draws a note in this window. A fretted note shows inside its columns. An open
    /// string sits on the nut, so it shows only while the window starts there: a window that has followed
    /// the hand up the neck has no nut in view, and an open note drawn on its left edge read as a note at
    /// that fret (ADR 0313, *What the phone showed*).
    func shows(_ note: FretNote) -> Bool {
        note.fret == 0 ? lowestFret <= 1 : (note.fret >= lowestFret && note.fret < lowestFret + span)
    }
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
    ///
    /// A **shaded range** (a Triads run kept in frets, ADR 0313 D6) is always in view, with a fret of neck
    /// either side so it reads as a place on the neck rather than the whole board. It never follows: the
    /// range is where the hand stays, so all of it shows at once, up to ten frets and the two either side.
    var displayLowestFret: Int {
        let shadeLow = shadedFrets.map { max(1, $0.lowerBound - 1) }
        guard let low = frettedNumbers.min() else { return shadeLow ?? 1 }
        return hasOpenNotes ? 1 : min(max(1, low), shadeLow ?? .max)
    }

    /// How many fret **columns** the board shows — enough to reach the highest fretted note (and the fret
    /// past a shaded range), but at least a comfortable four so a two-fret drill isn't a cramped sliver.
    var displayFretSpan: Int {
        let shadeHigh = shadedFrets.map { $0.upperBound + 1 }
        guard let high = [frettedNumbers.max(), shadeHigh].compactMap({ $0 }).max() else { return 4 }
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
    ///
    /// **A drill that names its chords follows the chord, not the note** (ADR 0313, *What the phone
    /// showed*). A triad's notes go back down the neck inside one chord (an F on G-B-e plays frets 10, 10,
    /// then 8), so following each note scrolled the window up for the F and straight back down for the C,
    /// twice for one chord. The fold steps chord by chord instead, over the frets of the whole chord: the
    /// window moves only when the chord changes, and the chord under the hand is always all in view.
    func displayWindow(activeIndex: Int?) -> FretWindow {
        let staticLow = displayLowestFret
        let staticSpan = displayFretSpan
        guard let activeIndex, noteCount > 0, staticSpan > Self.comfortableFretSpan, shadedFrets == nil else {
            return FretWindow(lowestFret: staticLow, span: staticSpan)
        }
        let width = Self.comfortableFretSpan
        let staticHigh = staticLow + staticSpan - 1
        let maxLow = max(staticLow, staticHigh - width + 1)   // never scroll past the run's own content
        let target = ((activeIndex % noteCount) + noteCount) % noteCount
        var low = staticLow                                   // the window starts anchored at the bottom
        if let chords, let current = chordIndex(at: target) {
            for chord in chords[...current] {
                guard let reach = frets(of: chord) else { continue }   // a chord that rests holds the window
                low = scrolled(low: low, toShow: reach, width: width, minLow: staticLow, maxLow: maxLow)
            }
            return FretWindow(lowestFret: low, span: width)
        }
        for index in 0...target {
            let fret = followedFret(activeIndex: index) ?? low
            low = scrolled(low: low, toShow: fret...fret, width: width, minLow: staticLow, maxLow: maxLow)
        }
        return FretWindow(lowestFret: low, span: width)
    }

    /// The scroll rule (ADR 0083 S5): keep the window put unless `frets` comes within `followEdgeMargin`
    /// of an edge, in which case scroll so they land `followTrailing` frets in from the edge they are
    /// *leaving* — a little history behind, the rest of the window the runway they are heading into (so
    /// the hand travels far before the next scroll). One note is a range of one fret; a chord is all of
    /// its frets, so the whole chord lands in view. Pure and total, clamped to `[minLow, maxLow]`.
    private func scrolled(low: Int, toShow frets: ClosedRange<Int>, width: Int, minLow: Int, maxLow: Int) -> Int {
        let high = low + width - 1
        if frets.upperBound > high - Self.followEdgeMargin {   // climbing → reached the right edge; scroll up
            return min(maxLow, frets.lowerBound - Self.followTrailing)
        }
        if frets.lowerBound < low + Self.followEdgeMargin {    // descending → reached the left edge; scroll down
            return max(minLow, frets.upperBound - (width - 1 - Self.followTrailing))
        }
        return low                                             // comfortably in view → hold
    }

    /// The frets a chord's notes sit on, lowest to highest. An open string counts as the nut's column, so
    /// a chord that rings one brings the nut back into view. `nil` for a chord with no notes (one that
    /// rests).
    private func frets(of chord: DrillChord) -> ClosedRange<Int>? {
        let played = chord.slots.compactMap { notes.indices.contains($0) ? notes[$0]?.fret : nil }.map { max(1, $0) }
        guard let lowest = played.min(), let highest = played.max() else { return nil }
        return lowest...highest
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
