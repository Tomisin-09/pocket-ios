import Foundation

/// The **bass chord vocabulary** (ADR 0163) — what a bassist actually plays when a chart says "C".
///
/// Not a four-string port of `ChordGrip`. The guitar system is CAGED: barre forms and triads laid on
/// string sets, slid by root. Bass isn't CAGED — the same finding ADR 0116 Slice 3 reached for scales,
/// for the same reason (four strings, an octave down, and a hand that spans frets rather than shapes).
/// Nor is a bass chord usually a triad: stacked thirds below E2 are mud, which is why bassists play
/// **dyads** — root with its fifth, its octave, or its tenth — and, higher up, three-note **shells**
/// that state the quality without the crowding.
///
/// So a shape here is an interval recipe, not a fingering table: string/fret offsets from the root,
/// slid to wherever the root sits. Two consequences worth knowing:
///
/// - **Generation is provable.** Every shape declares the intervals it spells, so a property test can
///   assert that the voicing produced at *every* root spells exactly those intervals — which is a
///   stronger guarantee than hand-authoring twelve transpositions and eyeballing them.
/// - **There is no bass barre or triad set to maintain.** The whole `ChordGrip` apparatus stays
///   guitar-only (ADR 0163 D4), and this file is the entire bass counterpart.
///
/// Authored in-house (T8): interval arithmetic and common-practice bass vocabulary, never anyone's
/// protected expression.
struct BassChordShape: Equatable, Identifiable, Sendable {
    /// Player-facing family name — "Power (root + 5th)", "Octave", "Minor 10th".
    let name: String
    /// What the chord is called once a root is chosen: "5" makes "C5", "m10" makes "Cm10". Empty for a
    /// shape whose name is the root alone (the octave, which is still just "C").
    let nameSuffix: String
    /// Semitones above the root, in the order the strings sound them. Always starts at `0` — every
    /// bass shape here is root-position, because the root *is* the bassist's job.
    let intervals: [Int]
    /// Which string each interval is played on, as an offset **towards the higher strings** from the
    /// root's string (0 = the root's own string, 1 = the next string up). Length matches `intervals`.
    let stringOffsets: [Int]

    var id: String { name }

    /// The lowest string the shape can be rooted on and still fit — the root's string must leave room
    /// for the highest string offset. Derived, so adding a shape can't get it wrong.
    var highestStringOffset: Int { stringOffsets.max() ?? 0 }
}

// MARK: - The curated set (ADR 0163 D3 — dyads + two shells)

extension BassChordShape {
    /// **Root + fifth.** The bass power dyad — the single most-played two-note shape on the
    /// instrument, one string apart and the same fret-span at every position.
    static let fifth = BassChordShape(name: "Power (root + 5th)", nameSuffix: "5",
                                      intervals: [0, 7], stringOffsets: [0, 1])

    /// **Root + octave.** Not a chord so much as the reach every bassist owns: same note, two strings
    /// up, two frets across. Named for the root alone because that is what it sounds.
    static let octave = BassChordShape(name: "Octave", nameSuffix: "",
                                       intervals: [0, 12], stringOffsets: [0, 2])

    /// **Root + major tenth.** The third, moved up an octave so it clears the mud — the standard way
    /// a bassist states "major" without stacking a third down low.
    static let majorTenth = BassChordShape(name: "Major 10th", nameSuffix: "10",
                                           intervals: [0, 16], stringOffsets: [0, 2])

    /// **Root + minor tenth.** The same move for a minor chord.
    static let minorTenth = BassChordShape(name: "Minor 10th", nameSuffix: "m10",
                                           intervals: [0, 15], stringOffsets: [0, 2])

    /// **Root · fifth · octave shell.** Three notes, no third — states the chord's frame and leaves the
    /// quality to whoever is playing it above you. Sits comfortably from the fifth fret up.
    static let fifthOctaveShell = BassChordShape(name: "Shell (root · 5 · 8)", nameSuffix: "5",
                                                 intervals: [0, 7, 12], stringOffsets: [0, 1, 2])

    /// **Root · ♭7 · tenth shell.** The dominant-seventh shell: the two notes that decide the chord's
    /// quality, spaced wide enough to read. The workhorse of walking-bass comping.
    static let seventhTenthShell = BassChordShape(name: "Shell (root · ♭7 · 10)", nameSuffix: "7",
                                                  intervals: [0, 10, 16], stringOffsets: [0, 1, 2])

    /// The full offered set, in the order the picker browses them: the three dyads a beginner reaches
    /// for first, then the two shells that need a hand further up the neck.
    static let all: [BassChordShape] = [
        .fifth, .octave, .majorTenth, .minorTenth, .fifthOctaveShell, .seventhTenthShell
    ]
}

// MARK: - Generation (T5 — pure, property-tested)

extension BassChordShape {
    /// The neck this generates on. Frets beyond it aren't playable, so a root that would push the
    /// shape past it has no voicing rather than an unreachable one.
    static let maxFret = 14

    /// Build the voicing for this shape rooted on `rootString` at `rootFret`.
    ///
    /// Returns `nil` when the shape doesn't fit — the root string is too high for its string offsets,
    /// or a note lands past `maxFret`. Refusing is deliberate: silently clamping a shape changes the
    /// intervals it spells, which is the one thing this type promises not to do.
    ///
    /// `rootString` is in the shared highest-first index (0 = G, 3 = low E), so "towards the higher
    /// strings" means a *decreasing* index — the reversal is done here, once, rather than at each
    /// call site.
    func voicing(rootString: Int, rootFret: Int, spelling: NoteSpelling = .default) -> ChordVoicing? {
        guard rootFret >= 0, rootString >= 0, rootString < ChordVoicing.bassStringCount,
              rootString - highestStringOffset >= 0 else { return nil }

        var frets: [Int?] = Array(repeating: nil, count: ChordVoicing.bassStringCount)
        let open = ChordVoicing.bassOpenMidi
        let rootMidi = open[rootString] + rootFret

        for (interval, offset) in zip(intervals, stringOffsets) {
            let string = rootString - offset
            // The fret that sounds `interval` semitones above the root on this string. Derived from
            // pitch rather than assumed from a fingering table, so the shape is correct on any
            // string pair — including the wider gap a non-uniform tuning would introduce.
            let fret = rootMidi + interval - open[string]
            guard fret >= 0, fret <= Self.maxFret else { return nil }
            frets[string] = fret
        }

        let rootName = spelling.name(pitchClass: rootMidi)
        return ChordVoicing("\(rootName)\(nameSuffix)", frets: frets)
    }

    /// Every playable voicing of this shape across the neck, lowest root first — what the picker
    /// browses. One entry per position: a root on the E string at fret 3 and the same pitch on the A
    /// string are different shapes to the hand, and a bassist picks between them.
    func voicings(spelling: NoteSpelling = .default) -> [ChordVoicing] {
        var built: [ChordVoicing] = []
        // Low strings first (highest index), then up the neck — the order a hand explores them.
        for rootString in stride(from: ChordVoicing.bassStringCount - 1, through: 0, by: -1) {
            for rootFret in 0...Self.maxFret {
                if let voicing = voicing(rootString: rootString, rootFret: rootFret, spelling: spelling) {
                    built.append(voicing)
                }
            }
        }
        return built
    }

    /// The voicing of this shape for a given **root pitch class**, at its lowest playable position —
    /// what "give me a C5" means when the player picks a root rather than a fret.
    func voicing(rootPitchClass: Int, spelling: NoteSpelling = .default) -> ChordVoicing? {
        let wanted = ((rootPitchClass % 12) + 12) % 12
        return voicings(spelling: spelling).first { $0.rootPitchClass == wanted }
    }
}
