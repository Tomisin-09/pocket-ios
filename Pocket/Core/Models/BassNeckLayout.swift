import Foundation

/// The **bass scale/arpeggio placement rule** (ADR 0116 Slice 3) — the 4-string sibling of the guitar
/// `CAGEDShape` / `ScaleNeckLayout` generators. Bass isn't CAGED: a bassist plays a scale as a single
/// **2-octave positional shape** across all four strings, one hand region, rooted on the low string.
///
/// Rather than truncate a 6-string guitar box (which strands the run mid-neck) or hand-author a parallel
/// geometry table, this reuses the *exact* tone ladder the guitar neck-spanning layouts already walk
/// (`ScaleNeckLayout.ascendingTones`, property-tested for the ascending/in-scale invariants) and lays it
/// across the bass strings with a bass notes-per-string schedule. So the only new, bass-specific logic is
/// **placement + labels** — the musical correctness is inherited.
///
/// Pure and Foundation-only (AGENTS.md): every function takes the engine's **highest-first** open-string
/// MIDI (`Tuning.engineOpenMidi`, index 0 = highest string), so the same code serves any monotonic
/// instrument — guitar's low-4 subset, a 5-string bass, etc. Reentrant tunings (ukulele) are out of scope
/// here for the same reason CAGED defers them (ADR 0116).
enum BassNeckLayout {
    /// The highest fret generation keeps every note at or below — a real neck's reach, matching
    /// `ScaleNeckLayout.maxFret`.
    static let maxFret = 24

    /// Bass ships **one** canonical box per key in v1: the 2-octave shape rooted on the low string, the
    /// shape a bassist learns first (the analogue of the guitar flagship, ADR 0091). Octave-shifted
    /// positions would run the top strings off the neck for higher roots, so multiple positions wait for
    /// their own follow-up. The editor hides the position stepper when this is 1.
    static let positionCount = 1

    /// The flagship (most-common) position — always the single low-string-rooted box.
    static let flagshipPosition = 1

    /// The 2-octave box for `offsets` (a scale's tone offsets, or an arpeggio's chord-tone degrees) in the
    /// key `root`, laid across the strings whose highest-first open MIDI is `openMidi`. The run opens on
    /// the tonic on the **lowest** string (open when the key allows, e.g. E/A/D/G) and climbs two octaves,
    /// a bass-idiomatic count of tones on each string. Every note is in `offsets` and the run ascends
    /// strictly — inherited from `ascendingTones` — so it's correct by construction, like the CAGED boxes.
    static func box(offsets: [Int], root: Int, openMidi: [Int]) -> [FretNote] {
        guard !offsets.isEmpty, openMidi.count >= 2 else { return [] }
        let strings = openMidi.count
        let lowString = strings - 1                       // engine index of the lowest string
        let lowOpenPitchClass = (((openMidi[lowString] % 12) + 12) % 12)
        // Lowest spot on the low string sounding the tonic — the open string itself when the key matches.
        let startFret = (((root - lowOpenPitchClass) % 12) + 12) % 12
        let startMidi = openMidi[lowString] + startFret
        let schedule = notesPerString(offsetCount: offsets.count, strings: strings)   // low → high
        let tones = ScaleNeckLayout.ascendingTones(fromMidi: startMidi, root: root,
                                                   offsets: offsets, count: schedule.reduce(0, +))
        var notes: [FretNote] = []
        var toneIndex = 0
        for step in 0..<strings {
            let string = lowString - step                 // low string up to the highest
            for _ in 0..<schedule[step] where toneIndex < tones.count {
                let fret = tones[toneIndex] - openMidi[string]
                notes.append(FretNote(string: string, fret: min(maxFret, max(0, fret))))
                toneIndex += 1
            }
        }
        return notes
    }

    /// How many tones sit on each string, **lowest string first**, for a 2-octave run: two octaves of the
    /// tone set plus the closing tonic, spread as evenly as possible with the remainder on the lower
    /// strings (where the hand starts). Pentatonic (5 tones) → `[3,3,3,2]`; diatonic (7) → `[4,4,4,3]`;
    /// a triad arpeggio (3) → `[2,2,2,1]` — the natural bass spread, no per-scale table.
    static func notesPerString(offsetCount: Int, strings: Int) -> [Int] {
        guard strings > 0 else { return [] }
        let total = 2 * offsetCount + 1
        let base = total / strings
        let remainder = total % strings
        return (0..<strings).map { base + ($0 < remainder ? 1 : 0) }
    }

    // MARK: - Pitch + labels (bass-specific; the guitar equivalents live on `CAGEDShape`)

    /// The MIDI pitch of a note on the string layout `openMidi`.
    static func midi(_ note: FretNote, openMidi: [Int]) -> Int {
        openMidi[min(max(0, note.string), openMidi.count - 1)] + note.fret
    }

    /// The interval (0…11) a note sounds above `root`, on the string layout `openMidi`.
    static func degree(of note: FretNote, root: Int, openMidi: [Int]) -> Int {
        (((midi(note, openMidi: openMidi) - root) % 12) + 12) % 12
    }

    /// The conventional name of a bass string by engine index (0 = G highest … 3 = E lowest for standard
    /// 4-string). Falls back to a 1-based number for any non-standard string count.
    static func stringName(_ index: Int, of count: Int) -> String {
        let standard = ["G", "D", "A", "E"]
        if count == standard.count, standard.indices.contains(index) { return standard[index] }
        return "\(index + 1)"
    }

    /// A plain-language anchor for the box (mirrors `CAGEDShape.rootAnchor`, ADR 0091): where its lowest
    /// root note sits — "Root on E · Fret 3", or "Root: open E" for an open-string tonic — read from the
    /// generated notes so it stays true for every key. Sentence-capitalised in step with the guitar
    /// anchor, since the two share the same position-label slot (2026-07-28).
    static func rootAnchor(in notes: [FretNote], root: Int, openMidi: [Int]) -> String {
        let count = openMidi.count
        guard let anchor = notes.filter({ degree(of: $0, root: root, openMidi: openMidi) == 0 })
            .min(by: { midi($0, openMidi: openMidi) < midi($1, openMidi: openMidi) }) else {
            let fret = notes.map(\.fret).filter { $0 > 0 }.min() ?? notes.map(\.fret).min() ?? 1
            return "From fret \(fret)"
        }
        return anchor.fret == 0
            ? "Root: open \(stringName(anchor.string, of: count))"
            : "Root on \(stringName(anchor.string, of: count)) · Fret \(anchor.fret)"
    }
}
