import Foundation

/// A chord read against the song's key (ADR 0308 D6): its Roman numeral, the degree its colour comes from
/// (D7), and whether it's the key's own.
///
/// - Counted from the key's own 1: in A minor, Am is **i**.
/// - The case says the kind: upper case major, lower case minor, **°** diminished, **ø** half-diminished,
///   **+** augmented, and a seventh or other extension follows (**V7**, **IIImaj7**), so G (VII) is never
///   read as G7 (VII7).
/// - The colour comes from the root's degree alone, so E and Em are both the 5.
/// - A root in the key with another kind than the key's own is **not the key's own**, and says what the
///   key's own would be. In a minor key, V and vii° count as the key's own (cadences).
/// - A root outside the key has no degree (silver) and carries its ♭ or ♯, from `RomanNumeral`'s tables.
///
/// Pure and Foundation-only (AGENTS.md), unit-tested in `ChordNumeralTests`.
struct ChordNumeral: Equatable, Sendable {
    /// The root's degree in the key, 1–7, which picks the colour (D7); `nil` for a root outside the key.
    let degree: Int?
    /// *I*, *iv*, *V7*, *vii°*, *♭VII*.
    let numeral: String
    /// The key's own chord on its root (D6). A root outside the key never is.
    let isKeysOwn: Bool
    /// The key's own chord on this root, for the line beside an outlined numeral: *iv*. `nil` otherwise.
    let keysOwn: String?

    /// Drawn outlined, not filled (D6): a root in the key with another kind than the key's own. One outside
    /// the key is silver instead.
    var isOutlined: Bool { degree != nil && !isKeysOwn }

    /// What a chord's numeral says of its kind, from its suffix.
    enum Kind: Equatable, Sendable {
        case major, minor, diminished, halfDiminished, augmented
        /// No third (*sus4*, *5*): neither major nor minor, so it's never not the key's own.
        case open

        var isLowerCase: Bool { self == .minor || self == .diminished || self == .halfDiminished }

        /// The kinds a key's own chord is compared by: a seventh doesn't change the family.
        var family: Kind { self == .halfDiminished ? .diminished : self }

        var mark: String {
            switch self {
            case .diminished: "°"
            case .halfDiminished: "ø"
            case .augmented: "+"
            case .major, .minor, .open: ""
            }
        }
    }

    /// The chord read against `key`, or `nil` with no key set: then there's no colour and no numeral (D6).
    static func read(root: Int, suffix: String, in key: MusicalKey) -> ChordNumeral? {
        guard let tonic = key.pitchClass, let quality = key.quality else { return nil }
        let minorKey = quality == .minor
        let interval = PieceLabel.normalised(root - tonic)
        let (kind, tail) = Self.kind(of: suffix)
        let scale = minorKey ? Self.minorScale : Self.majorScale
        // The leading tone's diminished chord counts as a minor key's own (vii°), though its root isn't in
        // the natural minor scale.
        let leadingTone = minorKey && interval == 11 && kind.family == .diminished
        let degree = leadingTone ? 7 : scale.firstIndex(of: interval).map { $0 + 1 }
        let base = leadingTone ? "VII" : (minorKey ? RomanNumeral.minorKey : RomanNumeral.majorKey)[interval]
        let numeral = (kind.isLowerCase ? base.lowercased() : base) + kind.mark + tail
        guard let degree, !leadingTone else {
            return ChordNumeral(degree: degree, numeral: numeral, isKeysOwn: leadingTone, keysOwn: nil)
        }
        let own = (minorKey ? Self.minorOwn : Self.majorOwn)[degree - 1]
        let isOwn = kind == .open || kind.family == own
            || (minorKey && degree == 5 && kind.family == .major)
        let ownNumeral = (own.isLowerCase ? base.lowercased() : base) + own.mark
        return ChordNumeral(degree: degree, numeral: numeral, isKeysOwn: isOwn, keysOwn: isOwn ? nil : ownNumeral)
    }

    /// A chord's kind, and what follows its numeral: *7*, *maj7*, *sus4*, or nothing.
    static func kind(of suffix: String) -> (Kind, String) {
        switch suffix {
        case "": (.major, "")
        case "m": (.minor, "")
        case "dim": (.diminished, "")
        case "dim7": (.diminished, "7")
        case "m7♭5": (.halfDiminished, "7")
        case "aug": (.augmented, "")
        case "mMaj7": (.minor, "maj7")
        case "5", "sus2", "sus4": (.open, suffix)
        case let minor where minor.hasPrefix("m") && !minor.hasPrefix("maj"): (.minor, String(minor.dropFirst()))
        default: (.major, suffix)
        }
    }

    private static let majorScale = [0, 2, 4, 5, 7, 9, 11]
    private static let minorScale = [0, 2, 3, 5, 7, 8, 10]
    /// The key's own triad on each degree, I to vii°.
    private static let majorOwn: [Kind] = [.major, .minor, .minor, .major, .major, .minor, .diminished]
    /// The natural minor's: i, ii°, III, iv, v, VI, VII (V counts too, in `read`).
    private static let minorOwn: [Kind] = [.minor, .diminished, .major, .minor, .minor, .major, .major]
}
