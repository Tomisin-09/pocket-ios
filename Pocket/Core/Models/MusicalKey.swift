import Foundation

/// A song's musical key as a closed vocabulary (ADR 0036): the 12 chromatic roots in
/// major or minor, plus `.unknown` for an unset or unrecognised value. This is the typed
/// replacement for the old free-text `Song.key` string — with a closed set the app can
/// validate input, sort harmonically, and (later) transpose, instead of matching arbitrary
/// strings like `"Am"` vs `"A minor"`.
///
/// **Storage:** `Song` still persists a raw `String` (`Song.key`); `Song.musicalKey` parses
/// it on read and writes the canonical `rawValue` on set. Keeping the stored attribute a
/// `String` means SwiftData's schema is unchanged — no migration, no store-wipe risk (the
/// ADR 0012 / CoreData 134110 rule, reaffirmed by ADR 0036 migration note 2). Legacy
/// free-text keys are folded onto cases by `parse(_:)` (the ADR 0036 "mapping pass") on
/// read, and rewritten canonically whenever a song is saved; anything unrecognised reads as
/// `.unknown`.
///
/// `rawValue` is the canonical stored string (`"C"`, `"C#m"`, `""` for unknown); `displayName`
/// is the human label (`"C major"`, `"A minor"`). Enharmonics are a display detail, not a
/// modelling one: `parse(_:)` accepts flats (`Bb`, `Db`…) and folds them onto the sharp
/// spellings the enum stores.
enum MusicalKey: String, CaseIterable, Identifiable, Comparable {
    case unknown = ""

    case cMajor = "C", cSharpMajor = "C#", dMajor = "D", dSharpMajor = "D#",
         eMajor = "E", fMajor = "F", fSharpMajor = "F#", gMajor = "G",
         gSharpMajor = "G#", aMajor = "A", aSharpMajor = "A#", bMajor = "B"

    case cMinor = "Cm", cSharpMinor = "C#m", dMinor = "Dm", dSharpMinor = "D#m",
         eMinor = "Em", fMinor = "Fm", fSharpMinor = "F#m", gMinor = "Gm",
         gSharpMinor = "G#m", aMinor = "Am", aSharpMinor = "A#m", bMinor = "Bm"

    var id: String { rawValue }

    enum Quality { case major, minor }

    /// `nil` only for `.unknown`.
    var quality: Quality? {
        guard self != .unknown else { return nil }
        return rawValue.hasSuffix("m") ? .minor : .major
    }

    /// Chromatic pitch class of the root, 0 (C) … 11 (B); `nil` for `.unknown`.
    var pitchClass: Int? {
        guard self != .unknown else { return nil }
        let root = rawValue.hasSuffix("m") ? String(rawValue.dropLast()) : rawValue
        return Self.sharpRoots.firstIndex(of: root)
    }

    /// Human label: `"C major"`, `"A minor"`, `"B♭ major"`; empty for `.unknown`. A key is the one
    /// thing that always knows how to spell itself (ADR 0123), so this reads the circle of fifths
    /// rather than the stored sharp root — `rawValue` stays `"A#"` for the store, the label reads
    /// "B♭ major". No preference is consulted: the key decides, and where the circle ties (F♯/G♭
    /// major, D♯/E♭ minor) the enum's own canonical sharp spelling stands.
    var displayName: String {
        guard let pitchClass, let quality else { return "" }
        let spelling = NoteSpelling.forMusicalKey(self) ?? .default
        return "\(spelling.name(pitchClass: pitchClass)) \(quality == .major ? "major" : "minor")"
    }

    /// Picker/menu label — like `displayName` but spells `.unknown` out as "Unknown".
    var pickerLabel: String { self == .unknown ? "Unknown" : displayName }

    /// The **root alone**, spelled as this key spells it — "B♭" for `.aSharpMajor`, "C♯" for
    /// `.cSharpMinor`; empty for `.unknown`. `displayName` minus the quality word, and by the same
    /// key-first rule (ADR 0123).
    ///
    /// Exists for the split key picker, where the root and the quality are chosen separately: the
    /// twelve root buttons have to be labelled *before* you know which one is selected, so each is
    /// labelled by the key it would produce. That means the row **re-spells when the quality flips**
    /// — D♯ minor and E♭ minor are the same pitch and the circle of fifths prefers a different one
    /// either side of it. That's the rule showing its work, not an inconsistency.
    var rootLabel: String {
        guard let pitchClass, quality != nil else { return "" }
        return (NoteSpelling.forMusicalKey(self) ?? .default).name(pitchClass: pitchClass)
    }

    /// Compose a key from its two independent halves. `pitchClass` wraps, so callers can pass a raw
    /// index without clamping; there is no way to reach `.unknown` from here, because "no root" and
    /// "no quality" aren't things this function can be handed — clearing is the caller's job.
    ///
    /// Lives on the enum rather than at the picker because `sharpRoots` is the canonical stored
    /// spelling and is `private` — and because the round-trip against `parse(_:)` is exactly the kind
    /// of boundary that needs a test rather than a reading.
    static func make(pitchClass: Int, quality: Quality) -> MusicalKey {
        let root = sharpRoots[((pitchClass % 12) + 12) % 12]
        return MusicalKey(rawValue: root + (quality == .minor ? "m" : "")) ?? .unknown
    }

    /// Sort key: by pitch class, major before minor; `.unknown` sorts last.
    private var sortIndex: Int {
        guard let pitchClass, let quality else { return Int.max }
        return pitchClass * 2 + (quality == .major ? 0 : 1)
    }

    static func < (lhs: MusicalKey, rhs: MusicalKey) -> Bool { lhs.sortIndex < rhs.sortIndex }

    /// Picker order: Unknown first, then every key by pitch (major before minor).
    static var pickerOrder: [MusicalKey] {
        [.unknown] + allCases.filter { $0 != .unknown }.sorted()
    }

    /// Sharp spellings indexed by pitch class — the canonical roots the enum stores.
    private static let sharpRoots = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Map a free-text key string to a case (the ADR 0036 mapping pass). Accepts canonical
    /// raw values, common spellings (`"A minor"`, `"Amin"`, `"a min"`), and flats (folded to
    /// sharps). Whitespace- and case-insensitive. Anything unrecognised → `.unknown`.
    static func parse(_ raw: String) -> MusicalKey {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !str.isEmpty else { return .unknown }

        let isMinor: Bool
        if str.contains("min") {            // "minor", "min"
            isMinor = true
            str = str.replacingOccurrences(of: "minor", with: "")
                     .replacingOccurrences(of: "min", with: "")
        } else if str.contains("maj") {     // "major", "maj"
            isMinor = false
            str = str.replacingOccurrences(of: "major", with: "")
                     .replacingOccurrences(of: "maj", with: "")
        } else if str.hasSuffix("m") {      // bare trailing "m" → minor ("am", "c#m")
            isMinor = true
            str = String(str.dropLast())
        } else {
            isMinor = false                  // bare root → major
        }
        str = str.trimmingCharacters(in: .whitespaces)

        guard let pitchClass = pitchClass(fromRoot: str) else { return .unknown }
        let canonical = sharpRoots[pitchClass] + (isMinor ? "m" : "")
        return MusicalKey(rawValue: canonical) ?? .unknown
    }

    /// Natural-note letters → pitch class.
    private static let naturalPitchClasses: [Character: Int] =
        ["c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11]
    /// Accidental characters → semitone offset (flats fold onto sharps).
    private static let accidentalOffsets: [Character: Int] =
        ["#": 1, "\u{266F}": 1, "b": -1, "\u{266D}": -1]

    /// Parse a bare root ("c", "c#", "db", "Bb") to a pitch class 0…11, folding flats onto
    /// sharps. Returns `nil` for anything that isn't a single letter A–G plus accidentals.
    private static func pitchClass(fromRoot root: String) -> Int? {
        guard let letter = root.first, var pitchClass = naturalPitchClasses[letter] else { return nil }
        for accidental in root.dropFirst() {
            guard let offset = accidentalOffsets[accidental] else { return nil }
            pitchClass += offset
        }
        return ((pitchClass % 12) + 12) % 12
    }
}
