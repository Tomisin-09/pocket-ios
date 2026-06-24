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
    case note           // neutral observation (default)
    case session        // a practice-session log

    var id: String { rawValue }

    /// The leading glyph rendered on the entry's kind chip.
    var emoji: String {
        switch self {
        case .goal: return "🎯"
        case .breakthrough: return "⚡️"
        case .struggle: return "🧗"
        case .note: return "📝"
        case .session: return "🎬"
        }
    }

    /// Chip label.
    var label: String {
        switch self {
        case .goal: return "Goal"
        case .breakthrough: return "Breakthrough"
        case .struggle: return "Struggle"
        case .note: return "Note"
        case .session: return "Session"
        }
    }

    /// The neutral fallback: a fresh entry, and any unrecognised stored raw value.
    static let `default`: EntryKind = .note

    /// Decode a stored raw value, folding empty/unknown to the default.
    init(raw: String) { self = EntryKind(rawValue: raw) ?? .default }

    /// Picker order: the action kinds first (goal → breakthrough → struggle),
    /// then the two neutral logs (note default, then session).
    static var pickerOrder: [EntryKind] { [.goal, .breakthrough, .struggle, .note, .session] }
}
