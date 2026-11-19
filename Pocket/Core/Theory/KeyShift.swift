import Foundation

/// **Another key** (ADR 0305): how far the audio is moved from the recording, in whole semitones.
///
/// Two shifts add up (D1): the song's, a fact about the recording (slice 2), and Active listening's, a key
/// to practise a lick in, which starts at 0 every visit (D3). **The total never goes more than six from the
/// recording** (D2): six either way reaches all twelve keys, and the further a phase-vocoder stretcher
/// shifts, the more it colours the sound. `TimeStretcher` clamps with `clamped` too, so nothing that asks
/// can get past it.
///
/// Pure and SwiftUI-free (AGENTS.md), so the clamps are unit-tested.
enum KeyShift {
    /// Six semitones either way (D2).
    static let reach = 6

    /// `semitones`, held within ±`reach`.
    static func clamped(_ semitones: Int) -> Int { min(reach, max(-reach, semitones)) }

    /// Where Active listening's stepper can go when the song is already moved by `song`: still all twelve
    /// keys, with the total inside ±`reach`. A song raised by 1 gives −7…+5 (D2).
    static func sessionRange(song: Int) -> ClosedRange<Int> {
        let song = clamped(song)
        return (-reach - song)...(reach - song)
    }

    /// `semitones` held inside `sessionRange(song:)`.
    static func session(_ semitones: Int, song: Int) -> Int {
        let range = sessionRange(song: song)
        return min(range.upperBound, max(range.lowerBound, semitones))
    }

    /// What the engine plays: the two added, never more than ±`reach` from the recording.
    static func total(song: Int, session: Int) -> Int { clamped(clamped(song) + session) }

    /// The stepper's value: *+3*, *−3*, or *0*. A real minus sign, as the mockup sets it.
    static func stepperValue(_ shift: Int) -> String {
        shift > 0 ? "+\(shift)" : shift < 0 ? "−\(-shift)" : "0"
    }

    // MARK: - A song's shift (D4)

    /// *1 semitone*, *3 semitones*.
    private static func semitones(_ shift: Int) -> String {
        "\(abs(shift)) semitone\(abs(shift) == 1 ? "" : "s")"
    }

    /// Edit song's line under *Raise or lower*: *As recorded*, *Up 1 semitone · F♯ minor → G minor*, or
    /// *Down 2 semitones* for a song with no key. The key stays the recording's; the line shows where the
    /// shift lands against it.
    static func songLine(key: MusicalKey, shift: Int) -> String {
        guard shift != 0 else { return "As recorded" }
        let moved = "\(shift > 0 ? "Up" : "Down") \(semitones(shift))"
        guard key != .unknown else { return moved }
        return "\(moved) · \(key.displayName) → \(key.moved(by: shift).displayName)"
    }

    /// The song player's chip, with the song's facts: *+1 semitone*, *−2 semitones*.
    static func chipLabel(_ shift: Int) -> String {
        "\(stepperValue(shift)) semitone\(abs(shift) == 1 ? "" : "s")"
    }

    /// What VoiceOver says for the chip: *Raised 1 semitone*.
    static func spokenSongShift(_ shift: Int) -> String {
        "\(shift > 0 ? "Raised" : "Lowered") \(semitones(shift))"
    }
}

/// **The key you're hearing** in Active listening (ADR 0305 D3, D5): the recording's key, moved by the
/// song's own shift (D4) and then by the session's, and everything the screen says about it. Pure, so
/// every line is tested.
///
/// The session counts from the song as it plays, so with a song raised by 1 the stepper's 0 is the raised
/// key, and *3 up* is three above that. Saved names are shown at the song's shift (D5), so the lines that
/// talk about them name the key they're shown in.
///
/// Spelled key-first (ADR 0123): *B♭ minor*, never *A♯ minor*. A song with no key says how far it moved
/// instead (*3 semitones up*).
struct HeardKey: Equatable, Sendable {
    /// The recording's key, as Edit song holds it.
    let recording: MusicalKey
    /// Active listening's shift, in semitones.
    let shift: Int
    /// The song's own shift (D4), which the session sits on top of. 0 for a song as recorded.
    var song: Int = 0

    var isShifted: Bool { shift != 0 }

    /// The key the song plays in before the session's shift: the recording's, moved by the song's.
    var played: MusicalKey { recording.moved(by: song) }

    /// The song's key moved by `shift`, or `.unknown` when the song has no key.
    var heard: MusicalKey { played.moved(by: shift) }

    /// How names are spelled for what you hear (D3): the heard key's spelling, or `nil` when the song has
    /// no key, so the caller falls back to the player's preference as it always has.
    var spelling: NoteSpelling? { NoteSpelling.forMusicalKey(heard) }

    /// *3 up*, *1 down*.
    var distance: String { "\(abs(shift)) \(shift > 0 ? "up" : "down")" }

    /// The line under the steppers: *G minor, as recorded*, or *B♭ minor · 3 up*. A song raised for your
    /// tuning says so at 0: *A♭ minor · song raised 1*. From six out, the same key is nearer the other way,
    /// and the line says so. With no key: *As recorded*, *Song raised 1*, *3 semitones up*.
    var line: String {
        guard isShifted else { return unshiftedLine }
        let semitones = abs(shift) == 1 ? "semitone" : "semitones"
        let moved = recording == .unknown
            ? "\(abs(shift)) \(semitones) \(shift > 0 ? "up" : "down")"
            : "\(heard.displayName) · \(distance)"
        guard abs(shift) >= KeyShift.reach else { return moved }
        return "\(moved) · same key as \(12 - abs(shift)) \(shift > 0 ? "down" : "up")"
    }

    /// The line at the session's 0: the recording, or the song as its own shift plays it.
    private var unshiftedLine: String {
        guard song != 0 else {
            return recording == .unknown ? "As recorded" : "\(recording.displayName), as recorded"
        }
        let raised = "\(song > 0 ? "raised" : "lowered") \(abs(song))"
        return recording == .unknown ? "Song \(raised)" : "\(played.displayName) · song \(raised)"
    }

    /// Where the names are made: *in B♭ minor*, or *3 up* with no key.
    private var whereHeard: String { recording == .unknown ? distance : "in \(heard.displayName)" }

    /// Where the saved names are shown: *in G minor*, the key the song plays in, or nothing with no key.
    private var whereSaved: String { recording == .unknown ? "" : " in \(played.displayName)" }

    /// The saved piece's card while shifted (D5): the names are the answer, so they're hidden.
    var hiddenNames: String {
        "Your names\(whereSaved) are hidden while you hear it \(whereHeard). They're the answer."
    }

    /// The card's button: *Name the notes in B♭ minor*.
    var nameButton: String { "Name the notes \(whereHeard)" }

    /// The card's footer: names made at a shift aren't kept (D5, Q2).
    var notKept: String {
        let saved = recording == .unknown ? "Your saved names" : "Your names\(whereSaved)"
        return "Names you make \(whereHeard) aren't kept. \(saved) stay as they are, and your taps carry over."
    }

    /// Name the notes' line at a shift (D5): *Naming in B♭ minor · your names in G minor stay as they are*.
    var namingLine: String {
        let saved = recording == .unknown ? "your saved names" : "your names\(whereSaved)"
        return "Naming \(whereHeard) · \(saved) stay as they are"
    }
}

extension MusicalKey {
    /// The same kind of key, `semitones` higher (or lower): G minor moved by 3 is B♭ minor. `.unknown`
    /// stays `.unknown`, and 0 changes nothing.
    func moved(by semitones: Int) -> MusicalKey {
        guard semitones != 0, let root = pitchClass, let quality else { return self }
        return .make(pitchClass: root + semitones, quality: quality)
    }
}
