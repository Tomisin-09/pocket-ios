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

/// Where the player is with the guitar (intake Q1 → planner starting difficulty + the fresh-exercise
/// tempo default). Self-rated, no judgement — Pocket never grades the player (ADR 0070).
enum ArtistExperience: String, CaseIterable, Identifiable {
    case justStarting
    case fewChords
    case comfortable
    case aWhile

    var id: String { rawValue }

    /// The intake option label ("Where are you with the guitar?").
    var displayName: String {
        switch self {
        case .justStarting: return "Just starting"
        case .fewChords: return "Know a few chords"
        case .comfortable: return "Comfortable, want to level up"
        case .aWhile: return "Been playing a while"
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
/// `Profile` stores an *array* of these. Ordering/emphasis consumers land later; the field is
/// collected now because the intake asks it once and the value is cheap to keep.
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

/// The dream (intake Q3 → planner emphasis mix). Consumed by the planner in Slice 3; collected now.
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
