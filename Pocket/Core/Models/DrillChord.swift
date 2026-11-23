import Foundation

/// One chord of a drill that plays chords (ADR 0313, *What the phone showed*): the slots it plays, and what
/// the board and the line over it say of it. A Triads run stamps these on the drill it expands to, so the
/// board can say which triad is under the hand: the line names it, its notes wear its colour, and its own
/// root is ringed.
///
/// **Transient**, like the drill's other render fields: never encoded, re-derived on each expansion.
/// Pure and Foundation-only (AGENTS.md), unit-tested in `DrillChordTests`.
struct DrillChord: Equatable, Sendable {
    /// The root's pitch class, 0 = C … 11 = B. The board rings it, and counts interval labels from it, while
    /// the chord plays.
    var root: Int
    /// What follows the root's name for the triad the board plays: "m", "dim", "". A Dm7 plays its Dm
    /// triad (D5), so its suffix is "m".
    var suffix: String
    /// The chord read against the run's key (ADR 0308 D6): the numeral the line shows, and the degree its
    /// colour comes from (D7).
    var numeral: ChordNumeral?
    /// What the line adds after the chord: the shape's inversion in a run of one chord, where the chord
    /// never changes and the inversion is the news, or *rests* where it has no shape.
    var detail: String?
    /// The slots it plays, within one cycle of the drill.
    var slots: Range<Int>

    /// "Am", spelled the way the board spells its notes: by the key, then the preference (ADR 0123).
    func name(spelling: NoteSpelling) -> String { spelling.name(pitchClass: root) + suffix }

    /// The same chord in another shape: a run of one chord moves between its inversions.
    func isSameChord(as other: DrillChord) -> Bool { root == other.root && suffix == other.suffix }
}

extension FretboardDrill {
    /// The index into `chords` of the chord playing at a slot, wrapping as the cycle does. `nil` with no
    /// slot, and for a drill that doesn't name its chords.
    func chordIndex(at slot: Int?) -> Int? {
        guard let slot, let chords, noteCount > 0 else { return nil }
        let wrapped = ((slot % noteCount) + noteCount) % noteCount
        return chords.firstIndex { $0.slots.contains(wrapped) }
    }

    /// The chord after the one at `index`, wrapping as the run loops: the line's *then*. `nil` when the
    /// drill has only one.
    func chord(after index: Int) -> DrillChord? {
        guard let chords, chords.count > 1 else { return nil }
        return chords[((index + 1) % chords.count + chords.count) % chords.count]
    }

    /// Whether the chord at `index` plays a position, given every slot that plays it
    /// (`plottedPositions`). A note two chords share counts for whichever is playing.
    func isPlayed(byChord index: Int?, slots: [Int]) -> Bool {
        guard let index, let chords, chords.indices.contains(index) else { return false }
        return slots.contains { chords[index].slots.contains($0) }
    }

    /// The pitch class the board reads against: the root of the chord playing, else the drill's own root
    /// (a Triads run's key). Interval labels count from it.
    func readingRoot(chord index: Int?) -> Int? {
        guard let index, let chords, chords.indices.contains(index) else { return rootPitchClass }
        return chords[index].root
    }

    /// The positions a chord sounds, each once, in the order it first plays them. Empty for a chord that
    /// rests.
    func notes(ofChord index: Int) -> [FretNote] {
        guard let chords, chords.indices.contains(index) else { return [] }
        var seen: [FretNote] = []
        for note in chords[index].slots.flatMap({ sounding(at: $0) }) where !seen.contains(note) { seen.append(note) }
        return seen
    }

    /// **Where the fingers just were** (ADR 0313 D8): while a chord plays, the notes of the shape before it
    /// that moved, which the board rings dashed so the nearest move can be seen. A note the two shapes
    /// share is a finger that stayed, so it isn't one. The shape before is the nearest earlier chord that
    /// played, so a chord that rests is passed over. The first chord has none, as the mockup draws it: on
    /// the run's first pass there is nowhere the fingers were. Empty while nothing plays, and while the
    /// chord playing rests.
    func notesJustLeft(chord index: Int?) -> Set<FretNote> {
        guard let index, chords?.indices.contains(index) == true else { return [] }
        let current = Set(notes(ofChord: index))
        guard !current.isEmpty else { return [] }
        for earlier in stride(from: index - 1, through: 0, by: -1) {
            let before = notes(ofChord: earlier)
            if !before.isEmpty { return Set(before).subtracting(current) }
        }
        return []
    }

    /// Whether the board rings a position as the root. While a chord plays, only its own root, among its
    /// own notes: a C elsewhere on the board isn't part of the shape under the hand. Otherwise every note
    /// on the drill's root, as it always has.
    func ringsRoot(_ note: FretNote, slots: [Int], chord index: Int?) -> Bool {
        guard let root = readingRoot(chord: index), pitchClass(of: note) == root else { return false }
        guard let index, let chords, chords.indices.contains(index) else { return true }
        return isPlayed(byChord: index, slots: slots)
    }
}
