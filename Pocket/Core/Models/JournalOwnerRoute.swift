import Foundation

/// **Where an entry's owner caption leads** (ADR 0142). The Journal space renders an owner label on
/// every item — "Little Wing · Verse riff", "Spider · exercise" — and until now it was dead text: the
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

    /// The stable business id of the unit this route lands on — the whole of the route's identity.
    var uid: UUID {
        switch self {
        case .exercise(let exercise): exercise.uid
        case .loop(let loop, _): loop.uid
        }
    }

    static func == (lhs: JournalOwnerRoute, rhs: JournalOwnerRoute) -> Bool { lhs.uid == rhs.uid }

    func hash(into hasher: inout Hasher) { hasher.combine(uid) }

    /// The route a timeline item's caption should follow, or `nil` when there is nowhere honest to
    /// go — so the caption stays plain text rather than becoming a tap that leads somewhere wrong.
    ///
    /// Two cases have no destination, both deliberately:
    /// - a **song**-owned take (ADR 0069 slice 4 never gave songs a standalone run surface), and
    /// - a loop that qualifies for **no mode at all** — one whose song's audio no longer resolves.
    static func route(for item: JournalTimeline.Item) -> JournalOwnerRoute? {
        switch item {
        case .note(let entry): route(loop: entry.loop, exercise: entry.exercise)
        case .take(let take): route(loop: take.loop, exercise: take.exercise)
        }
    }

    private static func route(loop: Loop?, exercise: Exercise?) -> JournalOwnerRoute? {
        if let exercise { return .exercise(exercise) }
        guard let loop, let mode = LoopModeAccess.modes(for: loop).first else { return nil }
        return .loop(loop, mode)
    }
}
