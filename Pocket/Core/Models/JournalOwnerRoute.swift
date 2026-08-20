import Foundation

/// **Where an entry's owner caption leads** (ADR 0142). The Journal space renders an owner label on
/// every item — "Slow Bend · Verse riff", "Spider · exercise" — and until now it was dead text: the
/// one place in the app that names a unit and can't take you to it.
///
/// Pure and UI-free, like its sibling `JournalTimeline`, so which screen an item points at is decided
/// once and can be tested without a `ModelContainer`. The view layer turns a route into a destination.
///
/// **Identity is the model's stable `uid`**, never `persistentModelID` — an item-driven navigation
/// destination keyed on the latter pops itself when SwiftData flips a temporary id to a permanent one
/// (ADR 0090; `docs/swiftdata-gotchas.md`).
enum JournalOwnerRoute: Hashable {
    /// An exercise — including a freeform block, which `ExerciseRunScreen` routes onward (ADR 0136).
    case exercise(Exercise)
    /// A loop, **in the mode it qualifies for**. A loop is not one screen: an unmeasured loop has no
    /// ramp to open (ADR 0138), so the caption opens whichever mode `LoopModeAccess` allows, in the
    /// established precedence — trainer, then ear, then improvise.
    case loop(Loop, LoopRunMode)
    /// The **routine a session note was written about** (2026-08-06). A session entry's caption was
    /// the last dead label on the feed: its practised-unit pills already opened their units, while the
    /// routine name above them — the thing the sitting actually *was* — went nowhere.
    case routine(Routine)

    /// The stable business id of the unit this route lands on — the whole of the route's identity.
    var uid: UUID {
        switch self {
        case .exercise(let exercise): exercise.uid
        case .loop(let loop, _): loop.uid
        case .routine(let routine): routine.uid
        }
    }

    static func == (lhs: JournalOwnerRoute, rhs: JournalOwnerRoute) -> Bool { lhs.uid == rhs.uid }

    func hash(into hasher: inout Hasher) { hasher.combine(uid) }

    /// The route a timeline item's caption should follow, or `nil` when there is nowhere honest to
    /// go — so the caption stays plain text rather than becoming a tap that leads somewhere wrong.
    ///
    /// Four cases have no destination, all deliberately:
    /// - a **song**-owned take (ADR 0069 slice 4 never gave songs a standalone run surface),
    /// - a loop that qualifies for **no mode at all** — one whose song's audio no longer resolves,
    /// - a **session** whose routine has since been deleted, or whose caller passed no library, and
    /// - an **orphaned** take or note whose unit was deleted (ADR 0151) — the row outlives the unit,
    ///   so both relationships are nil and there is nowhere to go. It still reads its snapshotted
    ///   caption; the caption is simply plain text, which is the ADR 0142 honesty rule.
    ///
    /// A **standalone** note has no caption at all, and a **metronome** note (ADR 0160 §6) has one
    /// that deliberately stays plain: the metronome screen exists, but opening it would restore
    /// whatever state it was left in rather than the sitting the note describes, so the tap would
    /// promise a destination it can't reach. Both fall out of the relationship test below, which is
    /// nil for either — stated here because the *reason* differs from an orphan's.
    ///
    /// A session resolves through `routines` because its owner is a **loose id copy** rather than a
    /// relationship (ADR 0143) — the same trade, and the same expected failure, as the unit pills
    /// below. `routines` defaults to empty so the take/unit callers, which have no session to resolve,
    /// don't have to fetch a library they'd never read.
    static func route(for item: JournalTimeline.Item,
                      routines: [Routine] = []) -> JournalOwnerRoute? {
        switch item {
        case .note(let entry):
            if entry.ownerKind == .session {
                guard let uid = entry.routineUID,
                      let routine = routines.first(where: { $0.uid == uid }) else { return nil }
                return .routine(routine)
            }
            return route(loop: entry.loop, exercise: entry.exercise)
        case .take(let take):
            return route(loop: take.loop, exercise: take.exercise)
        }
    }

    /// The route one of a **session** entry's practised-unit pills should follow (ADR 0143), or `nil`
    /// when there is nowhere honest to go.
    ///
    /// Unlike the item factory above, this resolves a **loose id copy** rather than following a
    /// relationship — that is the deletion-safety trade the session entry makes, and it means failure
    /// is an ordinary outcome, not an error. Three ways to get `nil`, all expected:
    /// - the unit was **deleted** since the session (the entry survives it; the link does not),
    /// - the loop qualifies for **no run mode** (its song's audio no longer resolves, ADR 0138), or
    /// - `kindRaw` names a kind this version doesn't know.
    ///
    /// Pass the library the caller already has in hand; this does no fetching of its own, so it stays
    /// pure and testable with uninserted models.
    static func route(for ref: SessionUnitRef,
                      exercises: [Exercise], loops: [Loop]) -> JournalOwnerRoute? {
        switch ref.kind {
        case .exercise:
            guard let exercise = exercises.first(where: { $0.uid == ref.uid }) else { return nil }
            return .exercise(exercise)
        case .loop:
            guard let loop = loops.first(where: { $0.uid == ref.uid }) else { return nil }
            return route(loop: loop, exercise: nil)
        case nil:
            return nil
        }
    }

    private static func route(loop: Loop?, exercise: Exercise?) -> JournalOwnerRoute? {
        if let exercise { return .exercise(exercise) }
        guard let loop, let mode = LoopModeAccess.modes(for: loop).first else { return nil }
        return .loop(loop, mode)
    }
}
