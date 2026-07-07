import Foundation

/// What a single block in a practice **routine** is (ADR 0066 R3): a closed,
/// single-select set. A routine is an ordered list of these blocks; the player runs
/// each in turn (ADR 0066 R6).
///
/// Stored on `RoutineItem` as a `String` raw value (`kindRaw`) with a computed `kind`
/// accessor — **never** as a raw enum attribute on the `@Model` (the SwiftData
/// enum-attribute migration rule: a custom enum stored directly faults old rows on
/// read; `Loop.loopType` / `JournalEntry.kind` are the precedents). Unrecognised/empty
/// raw decodes to `.rest`, the inert default, so a malformed value degrades gracefully
/// (an unknown block simply carries no unit and is skipped).
///
/// Deliberately kept **SwiftData-free** (Foundation only) so the pure pacing layer
/// (`RoutineBudget`) can reason over it without importing the persistence stack (the
/// "pure logic stays pure" rule, AGENTS.md).
enum RoutineItemKind: String, CaseIterable, Identifiable, Codable {
    /// Deliberate drilling of a unit — the budgeted work (ADR 0014 R1). The only kind
    /// that counts against a time budget.
    case focused
    /// A warm-up unit — surfaced but **unbudgeted** (ADR 0014 R1); you warm up as long
    /// as you like.
    case warmup
    /// A full run-through / jam — surfaced but **unbudgeted** (ADR 0014 R1); we never
    /// tell you to stop *playing*.
    case play
    /// A between-blocks break (ADR 0014 R3). References no unit; the inert default.
    case rest

    var id: String { rawValue }

    /// The neutral fallback: any unrecognised/empty stored raw value reads as a rest,
    /// which carries no unit and is harmless if it ever surfaces.
    static let `default`: RoutineItemKind = .rest

    /// Decode a stored raw value, folding empty/unknown to the default.
    init(raw: String) { self = RoutineItemKind(rawValue: raw) ?? .default }

    /// A block that points at a practice unit (`Exercise`/`Loop`/`Song`). A `rest`
    /// carries none. Drives the "exactly one unit set" invariant and the player's
    /// skip-if-missing rule (ADR 0066 R4/R5).
    var carriesUnit: Bool { self != .rest }

    /// Whether this block counts against the session **time budget** (ADR 0014 R1):
    /// only `focused` does. Warm-up and play are surfaced but unbudgeted; a rest is a
    /// break, not work.
    var isBudgeted: Bool { self == .focused }
}
