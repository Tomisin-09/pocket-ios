import Foundation

/// What a loop journal entry *is* (ADR 0038): a closed, single-select set, brought
/// into V1 as a typed tag rather than plain text so there's no later text→enum
/// migration. Stored on `JournalEntry` as a `String` raw value (`kindRaw`) with a
/// computed `kind` accessor — **never** as a raw enum attribute on the `@Model`
/// (the SwiftData enum-attribute migration rule: a custom enum stored directly
/// faults old rows on read; `Loop.loopType` is the precedent). Unrecognised/empty
/// raw decodes to `.note`, the neutral default, so a malformed value degrades
/// gracefully.
enum EntryKind: String, CaseIterable, Identifiable, Codable {
    case goal           // an intention set — "get the bend clean at full tempo"
    case breakthrough   // it clicked — progress worth marking
    case struggle       // a sticking point — what's fighting back
    case idea           // something to try — a direction, not a result (ADR 0207 D10)
    case note           // neutral observation (default)
    case session        // a practice-session log
    case ear            // what you heard, training your ear on a loop (ADR 0104)
    case improvise      // what you played over a backing-track loop (ADR 0135)
    case transcribed    // worked out by ear: a save wrote it until ADR 0229; still yours to add by hand

    var id: String { rawValue }

    /// The leading glyph rendered on the entry's kind chip.
    var emoji: String {
        switch self {
        case .goal: return "🎯"
        case .breakthrough: return "⚡️"
        case .struggle: return "🧗"
        case .idea: return "💡"
        case .note: return "📝"
        case .session: return "🎬"
        case .ear: return "👂"
        case .improvise: return "🎸"
        case .transcribed: return "🧩"
        }
    }

    /// Chip label.
    var label: String {
        switch self {
        case .goal: return "Goal"
        case .breakthrough: return "Breakthrough"
        case .struggle: return "Struggle"
        case .idea: return "Idea"
        case .note: return "Note"
        case .session: return "Session"
        case .ear: return "Ear"
        case .improvise: return "Improv"
        case .transcribed: return "Transcribed"
        }
    }

    /// The neutral fallback: a fresh entry, and any unrecognised stored raw value.
    static let `default`: EntryKind = .note

    /// Decode a stored raw value, folding empty/unknown to the default.
    init(raw: String) { self = EntryKind(rawValue: raw) ?? .default }

    /// Picker order: the deliberate kinds first (goal → breakthrough → struggle → idea),
    /// then the two neutral logs (note default, then session), then the three
    /// mode-specific tags a loop earns (ear, improv, transcribed).
    ///
    /// 🧩 **Transcribed is in the picker on purpose** (ADR 0225). Count the notes writes it, but a
    /// lick worked out on paper is just as solved, and "solved" is always the player's declaration —
    /// never something the app infers.
    ///
    /// 💡 **Idea sits with the first three, not after the logs** (ADR 0207 D10). Like them it is
    /// something a player reaches for on purpose; unlike `.note` and `.session` it is never a
    /// default and never set by the app. That is the property the tag filter is built on, so the
    /// order states it.
    static var pickerOrder: [EntryKind] {
        [.goal, .breakthrough, .struggle, .idea, .note, .session, .ear, .improvise, .transcribed]
    }
}
