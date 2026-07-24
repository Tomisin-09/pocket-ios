import Foundation

/// **How a scale is laid on the neck** (ADR 0083 S4) — the orthogonal placement axis a `ScaleRun`
/// picks alongside its scale / root / position. All three rules share one generator, property-test and
/// viewport substrate; they differ only in *where the notes sit*.
///
/// Additive and defaulting to `.box`, so every scale authored before this axis existed decodes and
/// generates exactly as it did (ADR 0065 T4 — decode-time default, no store migration).
enum ScaleLayout: String, CaseIterable, Identifiable, Codable {
    /// Today's single CAGED box in one hand position — the **default**. Uses `octaves`.
    case box
    /// The **diagonal position-connecting shape**: start in a position and climb through adjacent
    /// boxes, linked by same-string slides (S2). Reproduces the extended-pentatonic reference diagrams
    /// by construction. Reads `position` as the starting anchor; defines its own neck reach, so
    /// `octaves` is ignored.
    case extended
    /// **Three scale tones per string** across the neck — its own regular placement rule, not a CAGED
    /// box. A legitimate drill on its own (sequencing is a separate, deferred axis, S4). Reads
    /// `position` as the starting pattern; defines its own reach, so `octaves` is ignored.
    case threePerString

    var id: String { rawValue }

    /// Forgiving decode — an unrecognised stored layout falls back to the box (the workhorse), mirroring
    /// the scale/kind fallbacks (ADR 0036).
    init(storage raw: String) { self = ScaleLayout(rawValue: raw) ?? .box }

    var displayName: String {
        switch self {
        case .box: return "Box"
        case .extended: return "Extended"
        case .threePerString: return "3 Notes / String"
        }
    }

    /// Only the box layout is bounded by octave count; the neck-spanning layouts define their own reach
    /// and hide the octaves control (S4).
    var usesOctaves: Bool { self == .box }
}

// MARK: - Which layouts a scale offers (musically honest, and keeps every shape on a real neck)

extension GuitarScale {
    /// The layouts this scale can be laid out with. **Extended** is the *minor/major pentatonic*
    /// diagonal (two tones per string bridged by slides — where the extended vocabulary lives; the
    /// blues scale's semitone ♭5 steps climb too slowly for the two-per-string diagonal, so it stays a
    /// box). **3-notes-per-string** is a *diatonic* device (a 7-tone scale gives an even three per
    /// string that stays on the neck — a pentatonic's wider gaps would climb ~18 frets and run off the
    /// board). The box suits every scale.
    var supportedLayouts: [ScaleLayout] {
        switch self {
        case .minorPentatonic, .majorPentatonic: return [.box, .extended]
        // The modes are 7-tone diatonic scales, so they take the even three-per-string climb like the
        // major and natural minor they sit between.
        case .major, .naturalMinor, .dorian, .phrygian, .lydian, .mixolydian, .locrian:
            return [.box, .threePerString]
        // The blues and bebop scales carry a chromatic passing tone the neck-spanning generators don't
        // model (and whose semitone steps don't climb the two-per-string diagonal) — box only.
        case .blues, .bebopMajor, .bebopDominant: return [.box]
        }
    }

    /// Whether this scale can be laid out the given way — the editor offers only supported layouts, and
    /// generation falls back to `.box` for an unsupported pairing (a forward-compat blob, say).
    func supports(_ layout: ScaleLayout) -> Bool { supportedLayouts.contains(layout) }
}

// MARK: - The two canonical extended-pentatonic fingerings (ADR 0083 S4, refined from player diagrams)

/// The extended (diagonal) pentatonic is **one pattern that repeats every two strings**, so there are
/// exactly **two** clean fingerings — they differ only in *which string-pair carries the slide* (the
/// player's two reference diagrams, confirmed 2026-07-12). Offering five arbitrary CAGED anchors
/// instead produced awkward 3-fret slides; these two both land the slide as a whole-step.
enum ExtendedPentatonicShape: Int, CaseIterable, Identifiable {
    /// Slides on the **A & G** strings — the higher-anchored diagonal (Image 1; the well-known one).
    case agSlide = 1
    /// Slides on the **D & B** strings — the lower-anchored diagonal (Image 2).
    case dbSlide

    var id: Int { rawValue }

    /// The nearest valid shape for a raw selector value (the run reuses `position`, clamped to 1…2).
    init(selector raw: Int) {
        self = ExtendedPentatonicShape(rawValue: min(max(1, raw), ExtendedPentatonicShape.allCases.count)) ?? .agSlide
    }

    /// Which strings carry the third, slid-into tone (5 = low E … 0 = high e).
    var seamStrings: Set<Int> {
        switch self {
        case .agSlide: return [4, 2]
        case .dbSlide: return [3, 1]
        }
    }

    /// A CAGED-style mnemonic for the shape — the box each diagonal opens out of, matching the player's
    /// own screenshots (the A-G shape sat in the A-shape region, the D-B shape in the D-shape region).
    var shapeLetter: String {
        switch self {
        case .agSlide: return "A"
        case .dbSlide: return "D"
        }
    }

    /// The scale-degree index (into the ascending tone set) the low-E string opens on, picked so **both**
    /// seam slides land as clean whole-steps. It differs between the two pentatonics because their
    /// interval order differs — a major pentatonic and its relative minor share the shape one degree
    /// apart (`.minorPentatonic` = `.majorPentatonic` index + 1, mod 5).
    func startDegreeIndex(for scale: GuitarScale) -> Int {
        let major = self == .agSlide ? 3 : 1
        return scale == .minorPentatonic ? (major + 1) % 5 : major
    }
}

// MARK: - Neck-spanning generators (pure — correct by construction, unit-tested; S4/S6/S10)

/// The regular, non-CAGED placement rules for the neck-spanning layouts. Kept a free namespace of pure
/// static functions over `FretNote` so the geometry stays SwiftUI-free and Foundation-only (AGENTS.md),
/// and `ScaleRun` just dispatches to it.
enum ScaleNeckLayout {
    /// The highest fret a real neck reaches — generation keeps every note at or below it (S10).
    static let maxFret = 24

    /// The scale tones' semitone offsets, sorted and de-duplicated to one octave — the ladder both
    /// generators climb. Internal (not private) so the bass placement rule (`BassNeckLayout`, ADR 0116)
    /// reuses this exact tone ladder rather than duplicating it.
    static func toneOffsets(_ scale: GuitarScale) -> [Int] {
        Array(Set(scale.intervals.map { (($0 % 12) + 12) % 12 })).sorted()
    }

    /// Ascending scale-tone MIDI pitches: `count` of them starting **at** `startMidi` (which must be a
    /// scale tone), each the next tone up. Pure — the ladder the placement rules walk. Internal so the
    /// bass placement rule (`BassNeckLayout`, ADR 0116) reuses it.
    static func ascendingTones(fromMidi startMidi: Int, root: Int,
                               offsets: [Int], count: Int) -> [Int] {
        guard !offsets.isEmpty, count > 0 else { return [] }
        let startOffset = (((startMidi - root) % 12) + 12) % 12
        var index = offsets.firstIndex(of: startOffset) ?? 0
        var midi = startMidi
        var tones: [Int] = [midi]
        while tones.count < count {
            let next = offsets[(index + 1) % offsets.count]
            var step = next - offsets[index]
            if step <= 0 { step += 12 }
            midi += step
            index = (index + 1) % offsets.count
            tones.append(midi)
        }
        return tones
    }

    /// **Three scale tones per string** (S4), diatonic. `position` (1…5) picks which scale degree the
    /// pattern starts on — the classic 3-NPS "pattern number"; the shape anchors that degree at its
    /// lowest fretted spot on the low E and lays three ascending tones on each string up to the high e.
    /// Every note is a scale tone and the run climbs strictly by construction; frets stay on a real neck
    /// (a 7-tone scale spans ~10 frets here, comfortably under the 24th).
    static func threePerString(scale: GuitarScale, root: Int, position: Int) -> [FretNote] {
        let offsets = toneOffsets(scale)
        guard !offsets.isEmpty else { return [] }
        let startDegree = min(max(0, position - 1), offsets.count - 1)
        let startPitchClass = (((root + offsets[startDegree]) % 12) + 12) % 12
        // The low E string (index 5) sounds pitch class 4 open; take the lowest *fretted* spot (skip the
        // open string so the pattern stays a movable fretted shape that climbs with position).
        let lowE = 5
        let rawFret = (((startPitchClass - GuitarScale.pitchClass(string: lowE, fret: 0)) % 12) + 12) % 12
        let startFret = rawFret == 0 ? 12 : rawFret
        let startMidi = CAGEDShape.openMidi[lowE] + startFret
        let tones = ascendingTones(fromMidi: startMidi, root: root, offsets: offsets, count: 3 * 6)
        // Three consecutive tones per string, low E (5) up to high e (0).
        return tones.enumerated().map { index, midi in
            let string = lowE - index / 3
            return FretNote(string: string, fret: min(maxFret, max(0, midi - CAGEDShape.openMidi[string])))
        }
    }

    /// The **extended (diagonal) pentatonic** (S4): three CAGED boxes stitched into one climb by sliding
    /// up on the seam strings. Two tones sit on each string; on the `shape`'s two seam strings a third
    /// tone is a same-string **slide** up into the next box (S2 — a slide articulates only a same-string
    /// shift), so the shape climbs the neck diagonally instead of staying in one box. The `shape` picks
    /// which string-pair slides (the two canonical fingerings) and the low-E starting degree that keeps
    /// both slides whole-steps. Returns the notes paired with a per-note **box group** (0/1/2) so the
    /// board can focus the box being played (S2b). Every note is a scale tone and the run climbs strictly
    /// by construction.
    static func extended(scale: GuitarScale, root: Int,
                         shape: ExtendedPentatonicShape) -> (notes: [FretNote], groups: [Int]) {
        let offsets = toneOffsets(scale)
        guard offsets.count >= 2 else { return ([], []) }
        let startDegree = min(max(0, shape.startDegreeIndex(for: scale)), offsets.count - 1)
        let startPitchClass = (((root + offsets[startDegree]) % 12) + 12) % 12
        let lowE = 5
        let rawFret = (((startPitchClass - GuitarScale.pitchClass(string: lowE, fret: 0)) % 12) + 12) % 12
        let startFret = rawFret == 0 ? 12 : rawFret
        let startMidi = CAGEDShape.openMidi[lowE] + startFret
        // Two tones per string, three on the shape's seam strings (the extra one is the slide).
        let seams = shape.seamStrings
        let counts = (0..<6).map { seams.contains(lowE - $0) ? 3 : 2 }
        let tones = ascendingTones(fromMidi: startMidi, root: root, offsets: offsets,
                                   count: counts.reduce(0, +))
        var notes: [FretNote] = []
        var groups: [Int] = []
        var toneIndex = 0
        for stringStep in 0..<6 {
            let string = lowE - stringStep
            for tone in 0..<counts[stringStep] {
                let fret = min(maxFret, max(0, tones[toneIndex] - CAGEDShape.openMidi[string]))
                toneIndex += 1
                // The third tone on a seam string is slid into from the tone below on the same string.
                let isSlide = tone == counts[stringStep] - 1 && seams.contains(string)
                notes.append(FretNote(string: string, fret: fret, technique: isSlide ? .slide : nil))
                groups.append(stringStep / 2)
            }
        }
        return (notes, groups)
    }
}
