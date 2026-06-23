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

    /// Human label: `"C major"`, `"A minor"`; empty for `.unknown`.
    var displayName: String {
        guard let pitchClass, let quality else { return "" }
        return "\(Self.sharpRoots[pitchClass]) \(quality == .major ? "major" : "minor")"
    }

    /// Picker/menu label — like `displayName` but spells `.unknown` out as "Unknown".
    var pickerLabel: String { self == .unknown ? "Unknown" : displayName }

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
