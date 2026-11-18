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
}

/// **The key you're hearing** in Active listening (ADR 0305 D3, D5): the recording's key, moved by the
/// session's shift, and everything the screen says about it. Pure, so every line is tested.
///
/// Spelled key-first (ADR 0123): *B♭ minor*, never *A♯ minor*. A song with no key says how far it moved
/// instead (*3 semitones up*).
struct HeardKey: Equatable, Sendable {
    /// The key the audio plays in before the session's shift: the recording's.
    let recording: MusicalKey
    /// Active listening's shift, in semitones.
    let shift: Int

    var isShifted: Bool { shift != 0 }

    /// The recording's key moved by `shift`, or `.unknown` when the song has no key.
    var heard: MusicalKey {
        guard let root = recording.pitchClass, let quality = recording.quality else { return .unknown }
        return .make(pitchClass: root + shift, quality: quality)
    }

    /// How names are spelled for what you hear (D3): the heard key's spelling, or `nil` when the song has
    /// no key, so the caller falls back to the player's preference as it always has.
    var spelling: NoteSpelling? { NoteSpelling.forMusicalKey(heard) }

    /// *3 up*, *1 down*.
    var distance: String { "\(abs(shift)) \(shift > 0 ? "up" : "down")" }

    /// The line under the steppers: *G minor, as recorded*, or *B♭ minor · 3 up*. At six, the same key is
    /// six the other way, and the line says so. With no key: *As recorded*, *3 semitones up*.
    var line: String {
        guard isShifted else {
            return recording == .unknown ? "As recorded" : "\(recording.displayName), as recorded"
        }
        let semitones = abs(shift) == 1 ? "semitone" : "semitones"
        let moved = recording == .unknown
            ? "\(abs(shift)) \(semitones) \(shift > 0 ? "up" : "down")"
            : "\(heard.displayName) · \(distance)"
        guard abs(shift) == KeyShift.reach else { return moved }
        return "\(moved) · same key as \(KeyShift.reach) \(shift > 0 ? "down" : "up")"
    }

    /// Where the names are made: *in B♭ minor*, or *3 up* with no key.
    private var whereHeard: String { recording == .unknown ? distance : "in \(heard.displayName)" }

    /// Where the saved names were made: *in G minor*, or nothing with no key.
    private var whereSaved: String { recording == .unknown ? "" : " in \(recording.displayName)" }

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
