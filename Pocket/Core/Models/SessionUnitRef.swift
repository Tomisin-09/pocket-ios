import Foundation

/// One unit that was practised in a routine session, **snapshotted** onto a session journal entry
/// (ADR 0143). A session entry belongs to no unit, so it carries its own record of what the sitting
/// consisted of — the "you practised…" header the entry is unreadable without.
///
/// A **loose copy**, never a SwiftData relationship: it holds the unit's stable `uid`, its title as
/// it read at the time, and which kind of unit it was. Deleting the exercise must not delete the
/// reflection written about the session it appeared in (the same rule `PracticeRun` states for
/// `unitUID`/`routineUID`). The cost is that a ref can go stale — resolving one is allowed to fail,
/// and `JournalOwnerRoute` returns `nil` when it does.
///
/// Pure and UI-free, like its sibling `JournalTimeline`, so the encoding round-trip is testable
/// without a `ModelContainer`. Persisted as **JSON in a `String` column**, never as a `Codable`
/// attribute — the SwiftData non-primitive-attribute rule (see `JournalEntry.kindRaw`).
struct SessionUnitRef: Codable, Hashable, Identifiable {
    /// Which kind of unit the `uid` names — the two that have a run screen to open. Songs are
    /// excluded at the source: they never got a standalone run surface (ADR 0069 / 0142 J5a).
    enum Kind: String, Codable {
        case exercise
        case loop
    }

    /// The unit's stable business id — never `persistentModelID` (ADR 0090).
    let uid: UUID
    /// The unit's name **at the time of the session**. Snapshotted, not looked up, so a renamed or
    /// deleted unit still reads truthfully in an old entry (ADR 0038).
    let title: String
    /// Backing storage for `kind` — a raw `String`, so a payload written by a future version naming
    /// a kind this one doesn't know decodes cleanly and simply resolves to nowhere.
    let kindRaw: String

    /// Typed view over `kindRaw`; `nil` for a kind this version doesn't recognise.
    var kind: Kind? { Kind(rawValue: kindRaw) }

    var id: UUID { uid }

    init(uid: UUID, title: String, kind: Kind) {
        self.uid = uid
        self.title = title
        self.kindRaw = kind.rawValue
    }

    /// Raw-string initialiser — for decoding and for tests that need an unrecognised kind.
    init(uid: UUID, title: String, kindRaw: String) {
        self.uid = uid
        self.title = title
        self.kindRaw = kindRaw
    }

    // MARK: - Persistence

    /// Encode a snapshot for storage. An empty list encodes to `nil` rather than `"[]"`, so "no
    /// units" and "never written" read the same way in the column.
    static func encode(_ refs: [SessionUnitRef]) -> String? {
        guard !refs.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(refs) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decode a stored snapshot. **Never throws and never traps**: a `nil`, empty or malformed
    /// payload reads as no units, so an unreadable snapshot degrades to a plainer entry rather than
    /// taking the Journal down with it.
    static func decode(_ raw: String?) -> [SessionUnitRef] {
        guard let raw, let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SessionUnitRef].self, from: data)) ?? []
    }
}
