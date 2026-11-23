import Foundation

// MARK: - The chips under the editor's board (ADR 0313 D8; pure, unit-tested in TriadsTogetherTests)

/// One chord of the run as the strip under the editor's board shows it (D8): its name and numeral as
/// written, its inversion, its frets, and *plays Dm*, *no shape* or *no triad* where those apply. The
/// strip has one chip per chord the run plays, in order, so chip *n* is the board's chord *n*
/// (`FretboardDrill.chords`), and the chip of the chord being played can be lit.
struct TriadChip: Equatable, Sendable {
    /// Why a chord plays nothing.
    enum Rest: Equatable, Sendable {
        /// A power chord has no third, so it has no triad (D5).
        case noTriad
        /// No shape of it fits between the frets (D6).
        case noShape
    }

    /// As written: "Dm7", "Bdim", "G5".
    var name: String
    /// As written, read in the key: *ii7*, *vii°*, *V5*.
    var numeral: String?
    /// The degree its colour comes from (ADR 0308 D7), the same as the board's for this chord.
    var degree: Int?
    /// The shape's inversion: 0 root position, 1 first, 2 second. `nil` for an augmented triad, which is
    /// the same shape in every inversion (D1), and for a chord that rests.
    var inversion: Int?
    /// The shape's frets, low string to high, as a chord chart prints them. `nil` for a chord that rests.
    var frets: [Int]?
    /// The triad a bigger chord plays: "Dm" for a Dm7 (D5).
    var playsAs: String?
    var rest: Rest?
    /// Which pass up the neck it's in, for a progression that climbs (D6). 0 for everything else.
    var pass: Int
    /// The first chord of a pass after the first, which the strip sets apart.
    var startsPass: Bool

    /// *ii7 · 1st inv*: the numeral, then the inversion where there is one.
    var shapeLine: String {
        [numeral, inversion.map(Self.shortInversionName)].compactMap { $0 }.joined(separator: " · ")
    }

    /// *5 6 5*, or why there's nothing to fret.
    var fretLine: String {
        switch rest {
        case .noTriad: return "no triad"
        case .noShape: return "no shape"
        case nil: return (frets ?? []).map(String.init).joined(separator: " ")
        }
    }

    /// What VoiceOver says: "Pass 2, Dm7, plays Dm, ii7, 1st inversion, frets 5 6 5".
    var spoken: String {
        var parts = startsPass ? ["Pass \(pass + 1)"] : []
        parts.append(name)
        if let playsAs { parts.append("plays \(playsAs)") }
        if let numeral { parts.append(numeral) }
        if let inversion { parts.append(TriadRun.inversionName(inversion).lowercased()) }
        switch rest {
        case .noTriad: parts.append("no triad, so it rests")
        case .noShape: parts.append("no shape between these frets, so it rests")
        case nil: parts.append("frets " + fretLine)
        }
        return parts.joined(separator: ", ")
    }

    /// The mockup's: *root*, *1st inv*, *2nd inv*.
    static func shortInversionName(_ inversion: Int) -> String {
        switch inversion {
        case 1: return "1st inv"
        case 2: return "2nd inv"
        default: return "root"
        }
    }
}

extension TriadRun {
    /// The run's chords as chips, in the order they play (D8).
    func chips(preference: NoteSpelling = .default) -> [TriadChip] {
        let key = MusicalKey.make(pitchClass: tonic, quality: readsAsMinor ? .minor : .major)
        var previousPass = 0
        return placed(preference: preference).enumerated().map { index, item in
            let chord = item.chord
            let triad = chord.quality.triadQuality ?? chord.quality
            let written = ChordNumeral.read(root: chord.root, suffix: chord.quality.nameSuffix, in: key)
            let played = ChordNumeral.read(root: chord.root, suffix: triad.nameSuffix, in: key)
            let rest: TriadChip.Rest? = item.shape != nil ? nil : (chord.intervals == nil ? .noTriad : .noShape)
            defer { previousPass = item.pass }
            return TriadChip(name: chord.name, numeral: written?.numeral, degree: played?.degree,
                        inversion: triad == .augmented ? nil : item.shape?.inversion,
                        frets: item.shape?.frets, playsAs: chord.playsAs, rest: rest, pass: item.pass,
                        startsPass: index > 0 && item.pass != previousPass)
        }
    }
}
