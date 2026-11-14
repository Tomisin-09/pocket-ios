import Foundation

/// What the chord picker knows about the chord it was opened to **swap** (ADR 0297).
///
/// A swap used to open the same picker as *Add*, knowing nothing, so changing one chord meant finding
/// its shape again among sixty chips and choosing its root again from a menu. A swap is nearly always
/// one of two moves — *same root, another shape* (C → Cm7, the A-shape C → the E-shape C) or *same
/// shape, another root* (slide it) — and both need only what this carries: the chord's **root**, which
/// the picker's root row opens on, and the **shape** it was placed from, which is marked at every root.
///
/// Derived from the voicing's frets, never stored. A `ChordVoicing` keeps no record of the grip that
/// made it, and it doesn't need to: placing a grip is deterministic, so the frets say which one it was.
/// A chord that matches no grip — a custom one, or one placed before a grip's geometry changed (ADR
/// 0122) — still gets a root from its notes, and simply has no shape to mark.
struct ChordPickerCurrent: Equatable {
    /// The root the root row opens on. `nil` only when the voicing sounds nothing.
    let rootPitchClass: Int?
    /// The movable shape the chord was placed from, if it is one — marked at **every** root, because
    /// sliding the same shape is one of the two moves a swap is for.
    let grip: ChordGrip?
    /// The bass shape the chord is, if it is one (ADR 0164) — marked at every root, like a grip.
    let bassShape: BassChordShape?
    /// The chord's exact frets. A fixed chip — an open shape, one of My chords — is marked only when
    /// its frets are these: it can't move, so it is only "the current one" where it already is.
    let frets: [Int?]

    init(_ voicing: ChordVoicing) {
        let placement = ChordPicker.gripPlacement(of: voicing)
        grip = placement?.grip
        bassShape = ChordPicker.bassShape(of: voicing)
        frets = voicing.frets
        rootPitchClass = placement?.rootPitchClass ?? ChordPicker.root(of: voicing)
    }

    /// Whether a fixed chip with these frets is the chord being swapped.
    func isCurrent(frets other: [Int?]) -> Bool { other == frets }
}

extension ChordPicker {
    /// Every grip the Insert grid can place at a root — the ones a swap can recognise and mark.
    static let placeableGrips: [ChordGrip] = insertMovableGrips + insertTriadGrips + insertTier2Grips

    /// The grip and root a guitar voicing was placed from, or `nil` if it isn't one of them.
    ///
    /// Read the root off the fret the grip keeps its root on, then place the grip there and compare
    /// every string: one placement per grip rather than twelve, and exact, because `voicing(rootPitchClass:)`
    /// is the only way a grip becomes a chord. Fingers and the name are ignored — a name follows the
    /// accidental preference (ADR 0123), so `A♯` and `B♭` are the same placement.
    static func gripPlacement(of voicing: ChordVoicing) -> (grip: ChordGrip, rootPitchClass: Int)? {
        guard voicing.frets.count == ChordVoicing.stringCount else { return nil }
        for grip in placeableGrips {
            let rootString = grip.rootString.rawValue
            guard let rootFret = voicing.frets[rootString] else { continue }
            let root = GuitarScale.pitchClass(string: rootString, fret: rootFret)
            if grip.voicing(rootPitchClass: root).frets == voicing.frets {
                return (grip, root)
            }
        }
        return nil
    }

    /// The bass shape a four-string voicing is, at any of the places it can sit, or `nil`.
    static func bassShape(of voicing: ChordVoicing) -> BassChordShape? {
        guard voicing.isBass else { return nil }
        return BassChordShape.all.first { shape in
            shape.voicings().contains { $0.frets == voicing.frets }
        }
    }

    /// The root a chord is *of*, for the root row and for filtering the fixed chips by it.
    ///
    /// A placed grip knows its root exactly — a triad inversion has its 3rd or 5th in the bass, so the
    /// bass note would be wrong. A bass chord is root-in-the-bass by construction (ADR 0164). Anything
    /// else is read by `ChordNamer` (ADR 0093), which reads *D/F♯* as D rather than F♯, and a chord it
    /// can't name falls back to its lowest note.
    static func root(of voicing: ChordVoicing) -> Int? {
        if let placement = gripPlacement(of: voicing) { return placement.rootPitchClass }
        if voicing.isBass { return voicing.rootPitchClass }
        return ChordNamer.candidates(for: voicing).first?.rootPitchClass ?? voicing.rootPitchClass
    }

    /// Whether a fixed chip (an open shape, one of My chords) belongs under the chosen root. Every chip
    /// belongs when no root is chosen — that's *Any*, the picker as it was before ADR 0297.
    static func fixedChord(_ voicing: ChordVoicing, isAt root: Int?) -> Bool {
        guard let root else { return true }
        return Self.root(of: voicing) == root
    }
}
