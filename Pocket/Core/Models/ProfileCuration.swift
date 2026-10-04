import Foundation

/// The **curation vocabulary** for the local artist profile (ADR 0113, Slice 2): the four
/// declared-intent fields the first-launch intake collects, plus the pure mappings from those
/// answers to the two consumers that exist today — a fresh exercise's default command tempo and the
/// planner's default session length. Goal/dream is collected here but consumed later (Slice 3, the
/// planner emphasis mix).
///
/// Everything here is **UI-free and unit-tested** (AGENTS.md: pure logic stays pure). The enums are
/// `String`-raw so `Profile` can store the raw value and compute the case back — the profile never
/// stores a custom enum directly (the enum-attribute migration crash, `docs/swiftdata-gotchas.md`).
/// Nothing here is PII: these are musical preferences, not attributes of a person.

/// **What the player plays** (ADR 0248) — the intake's first question. Guitar and bass are what the app's
/// neck, drills and Toolkit are built for; everyone else came for a song they can loop, slow down and keep,
/// and a metronome. That split, `fretboard`, is the one thing the rest of the app reads: it decides
/// whether the first run seeds guitar drills and asks for goals built from them.
///
/// Not `Instrument` (ADR 0116), which is the neck an exercise is drawn on and has only the two. A
/// pianist's answer has no neck to map to, and making it one would put an app-wide mode back that 0116
/// rejected.
enum PlayedInstrument: String, CaseIterable, Identifiable {
    case guitar
    case bass
    case piano
    case singing
    case producing
    case drums
    case ukulele
    case violin
    case other

    var id: String { rawValue }

    /// The intake's option, in the order Tomisin set: guitar, bass, then the rest (2026-10-03).
    var displayName: String {
        switch self {
        case .guitar: return "Guitar"
        case .bass: return "Bass"
        case .piano: return "Piano or keys"
        case .singing: return "Singing"
        case .producing: return "Producing"
        case .drums: return "Drums"
        case .ukulele: return "Ukulele"
        case .violin: return "Violin"
        case .other: return "Something else"
        }
    }

    /// The neck this answer plays on, or `nil` when the app has none for it. Ukulele is fretted, but its
    /// re-entrant tuning has no neck here yet (ADR 0116), so it leans on songs with the rest.
    var fretboard: Instrument? {
        switch self {
        case .guitar: return .guitar
        case .bass: return .bass
        case .piano, .singing, .producing, .drums, .ukulele, .violin, .other: return nil
        }
    }

    /// Whether the first run leans on songs, loops and the metronome rather than guitar drills (ADR 0248).
    var leansOnSongs: Bool { fretboard == nil }

    /// What the experience question asks about: *Where are you with the piano?*, *…with singing?*
    var experienceSubject: String {
        switch self {
        case .guitar: return "the guitar"
        case .bass: return "the bass"
        case .piano: return "the piano"
        case .singing: return "singing"
        case .producing: return "producing"
        case .drums: return "the drums"
        case .ukulele: return "the ukulele"
        case .violin: return "the violin"
        case .other: return "your instrument"
        }
    }

    /// *Know a few chords*, in this instrument's words: the experience card's second answer (ADR 0248 D3).
    var aFewLabel: String {
        switch self {
        case .guitar, .piano, .ukulele: return "Know a few chords"
        case .bass: return "Know a few lines"
        case .singing: return "Know a few songs"
        case .producing: return "Finished a few tracks"
        case .drums: return "Know a few grooves"
        case .violin: return "Know a few tunes"
        case .other: return "Know the basics"
        }
    }

    /// *Been playing a while*, in this instrument's words: the experience card's last answer.
    var aWhileLabel: String {
        switch self {
        case .singing: return "Been singing a while"
        case .producing: return "Been producing a while"
        default: return "Been playing a while"
        }
    }

    /// The answer an older profile implies: before this question, the only one asked was Guitar or Bass.
    init(fretboard: Instrument) {
        switch fretboard {
        case .guitar: self = .guitar
        case .bass: self = .bass
        }
    }
}

/// Where the player is with what they play (intake Q2 → planner starting difficulty + the fresh-exercise
/// tempo default). Self-rated, no judgement — Pocket never grades the player (ADR 0070).
enum ArtistExperience: String, CaseIterable, Identifiable {
    case justStarting
    case fewChords
    case comfortable
    case aWhile

    var id: String { rawValue }

    /// The intake option label ("Where are you with the guitar?"), and Settings' — the guitar's words.
    var displayName: String { displayName(for: nil) }

    /// The label for someone who plays `plays` (ADR 0248): *a few chords* means nothing to a singer. The
    /// stored answer is the same either way; only the words follow the instrument. `nil` reads as guitar,
    /// the question as it was asked before there was a first question.
    func displayName(for plays: PlayedInstrument?) -> String {
        switch self {
        case .justStarting: return "Just starting"
        case .comfortable: return "Comfortable, want to level up"
        case .fewChords: return (plays ?? .guitar).aFewLabel
        case .aWhile: return (plays ?? .guitar).aWhileLabel
        }
    }

    /// The command tempo (BPM) a freshly-created exercise pre-fills for this level (ADR 0113 S2
    /// consumer). Modest and rising — a beginner starts near the engine floor and re-anchors on the
    /// first run; a seasoned player starts where the seeded drills sit (70–90). Never a ceiling: the
    /// command stepper is right there to change it.
    var defaultCommandTempo: Int {
        switch self {
        case .justStarting: return 50
        case .fewChords: return 60
        case .comfortable: return 75
        case .aWhile: return 90
        }
    }
}

/// What the player wants to play (intake Q2 → preset ordering + planner emphasis). Multi-select, so a
/// `Profile` stores an *array* of these. The planner-emphasis consumer (`GenreSkillMap` →
/// `PracticeEmphasis`, ADR 0113 S3) lifts the skills each declared genre leans on.
enum MusicGenre: String, CaseIterable, Identifiable {
    case rock
    case blues
    case pop
    case folkAcoustic
    case jazz
    case funkSoul
    case rnbNeoSoul
    case metal
    case singerSongwriter

    var id: String { rawValue }

    /// The intake chip label ("What do you want to play?").
    var displayName: String {
        switch self {
        case .rock: return "Rock"
        case .blues: return "Blues"
        case .pop: return "Pop"
        case .folkAcoustic: return "Folk/Acoustic"
        case .jazz: return "Jazz"
        case .funkSoul: return "Funk/Soul"
        case .rnbNeoSoul: return "R&B/Neo-soul"
        case .metal: return "Metal"
        case .singerSongwriter: return "Singer-songwriter"
        }
    }
}

/// The dream (intake Q3 → planner emphasis mix, ADR 0113 Slice 3). Tilts the planner toward a
/// practice **mode** (`PracticeEmphasis`): the whole-fretboard grind, the theory desk, the songbook,
/// or an easy expressive noodle.
enum MusicalDream: String, CaseIterable, Identifiable {
    case playSongs
    case writeMusic
    case getGood
    case unwind

    var id: String { rawValue }

    /// The intake option label ("What's the dream?").
    var displayName: String {
        switch self {
        case .playSongs: return "Play songs I love"
        case .writeMusic: return "Write my own music"
        case .getGood: return "Get properly good"
        case .unwind: return "Just unwind"
        }
    }

    /// The single practice **mode** this dream tilts a session toward (ADR 0113 S3 emphasis, Slice 3
    /// consumer). Songs → `repertoire`; writing → the off-guitar theory/songwriting desk; getting
    /// good → the technique speed-ramp; unwinding → low-pressure expressive `loopDrill` playing
    /// (scales, bends, feel) rather than the grind. One mode each keeps the tilt legible — it's a
    /// nudge, never the whole plan.
    var emphasisedMode: SkillMode {
        switch self {
        case .playSongs: return .repertoire
        case .writeMusic: return .offGuitar
        case .getGood: return .speedRamp
        case .unwind: return .loopDrill
        }
    }
}

/// How long the player practises on a typical day (intake Q4 → planner session length + tempo
/// defaults). Maps to one of the planner's `SessionLength` presets.
enum PracticeMinutes: String, CaseIterable, Identifiable {
    case short
    case medium
    case long
    case varies

    var id: String { rawValue }

    /// The intake option label ("How long most days?").
    var displayName: String {
        switch self {
        case .short: return "10–15 min"
        case .medium: return "~30 min"
        case .long: return "45+ min"
        case .varies: return "It varies"
        }
    }

    /// The planner session-length preset this seeds (ADR 0113 S2 consumer). "It varies" falls back to
    /// the planner's own short default rather than guessing long. Only a *default* — the planner's
    /// duration picker overrides it freely.
    var preferredSessionLength: SessionLength {
        switch self {
        case .short: return .quick
        case .medium: return .focused
        case .long: return .full
        case .varies: return .default
        }
    }
}
