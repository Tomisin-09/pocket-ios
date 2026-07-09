import Foundation
import SwiftData

/// A **practice routine** (ADR 0066): a multi-unit *session* container — an ordered
/// sequence of drills, loops, song run-throughs and rests you work through in one
/// sitting. Distinct from the intra-exercise tempo ramp (`RoutineStairs`/`CommandRamp`),
/// which is the staircase *inside* a single exercise; a `Routine` strings whole units
/// together.
///
/// This is the **container**; a player runs it end-to-end (ADR 0066 R6, a later slice)
/// and the planner (ADRs 0014/0015/0016, deferred) becomes just another producer of
/// this same model. Follows the established model discipline (ADR 0011/0036): a
/// business `uid`, **declaration defaults** on every non-optional attribute (the
/// CoreData 134110 rule — `init`-only defaults wipe the store), and any enum stored
/// through a `String` backing field (`RoutineItem.kindRaw`), never as a raw enum
/// attribute.
@Model
final class Routine {
    /// Stable business id — list diffing / selection / undo, like `Exercise`/`Loop`.
    var uid: UUID

    /// The routine's name ("Morning warm-up", "Alt-picking builder"). Empty until named,
    /// mirroring `Exercise.name`.
    var name: String = ""

    /// When the routine was created — the default library sort key.
    var dateAdded: Date = Date.now

    /// When this routine was last *practised* — set on each run (ADR 0066 follow-on), distinct from
    /// `dateAdded` (creation) and from the ephemeral `RoutineSession` cursor (mid-run position, not
    /// history). Drives the home hub's "recent routines" rail. `nil` until run once. Additive optional
    /// (CoreData 134110 rule): a declaration default keeps SwiftData lightweight migration clean.
    var lastPracticed: Date?

    /// The ordered blocks. **Cascade-owned**: deleting the routine deletes its items (but
    /// never the units those items *reference* — that link nullifies, see `RoutineItem`).
    /// Declaration default keeps SwiftData lightweight migration additive (CoreData 134110).
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    var items: [RoutineItem] = []

    /// Items in play order. `@Relationship` arrays are not a dependable ordering, so the
    /// order is read off the explicit `RoutineItem.order` (ADR 0066 R2), the same
    /// discipline as `Song.loopsByStart`.
    var orderedItems: [RoutineItem] { RoutineItem.ordered(items) }

    init(name: String = "", dateAdded: Date = .now) {
        self.uid = UUID()
        self.name = name
        self.dateAdded = dateAdded
    }
}

/// One block in a `Routine` (ADR 0066 R3): a typed step that either points at a single
/// practice **unit** (`Exercise`, `Loop`, or `Song`) or is a structural `rest`.
///
/// **Unit reference, not ownership (R4/R5).** A unit-bearing item points at *exactly
/// one* of `exercise`/`loop`/`song` via a typed optional relationship — the ADR 0058
/// polymorphic pattern (typed optionals keep SwiftData's inverse/nullify integrity; a
/// generic `ownerKind + ownerID` loses it). The item references the live unit, so
/// editing the drill reflects here. Deleting the referenced unit **nullifies** the link
/// (never cascade-deletes the routine); an item whose unit went missing is *skipped* by
/// the player (`isOrphaned`), not a crash.
@Model
final class RoutineItem {
    /// Stable business id — list diffing / reorder / undo.
    var uid: UUID

    /// Explicit play order within the routine (ADR 0066 R2). The player and
    /// `Routine.orderedItems` sort by this; we never lean on relationship-array order.
    var order: Int = 0

    /// Backing storage for `kind` — a plain `String`, **not** the enum (the SwiftData
    /// enum-attribute migration rule; see `JournalEntry.kindRaw`). Empty/unknown reads as
    /// `.rest`. Declaration default so the column always has a value.
    var kindRaw: String = RoutineItemKind.default.rawValue

    /// Typed view over `kindRaw`; unrecognised/empty reads as the default (`.rest`).
    var kind: RoutineItemKind {
        get { RoutineItemKind(raw: kindRaw) }
        set { kindRaw = newValue.rawValue }
    }

    /// Back-reference to the owning routine (inverse of `Routine.items`, cascade-owned).
    var routine: Routine?

    /// The referenced unit — **exactly one** of these is set on a unit-bearing block, and
    /// none on a `rest`. Each is the inverse of the matching `…​.routineItems` relationship
    /// on the unit, with a **nullify** delete rule so deleting a unit clears the link and
    /// leaves the routine intact (ADR 0066 R5). Additive optional relationships (CoreData
    /// 134110 rule).
    var exercise: Exercise?
    var loop: Loop?
    var song: Song?

    init(kind: RoutineItemKind = .rest, order: Int = 0) {
        self.uid = UUID()
        self.order = order
        self.kindRaw = kind.rawValue
    }

    // MARK: Factories — keep the "exactly one unit" invariant honest

    /// A block drilling/playing an **exercise** (default `focused`).
    static func item(_ exercise: Exercise, kind: RoutineItemKind = .focused,
                     order: Int = 0) -> RoutineItem {
        let routineItem = RoutineItem(kind: kind, order: order)
        routineItem.exercise = exercise
        return routineItem
    }

    /// A block drilling/playing a **loop** (default `focused`).
    static func item(_ loop: Loop, kind: RoutineItemKind = .focused,
                     order: Int = 0) -> RoutineItem {
        let routineItem = RoutineItem(kind: kind, order: order)
        routineItem.loop = loop
        return routineItem
    }

    /// A block running a **song** end-to-end (default `play` — a repertoire run-through).
    static func item(_ song: Song, kind: RoutineItemKind = .play,
                     order: Int = 0) -> RoutineItem {
        let routineItem = RoutineItem(kind: kind, order: order)
        routineItem.song = song
        return routineItem
    }

    /// A `rest` block — a break between blocks, referencing no unit.
    static func rest(order: Int = 0) -> RoutineItem {
        RoutineItem(kind: .rest, order: order)
    }

    // MARK: Derived state

    /// Whether a referenced unit is still resolvable — true when one of the three unit
    /// relationships is set. A unit block whose unit was deleted reads `false` (the
    /// nullify left all three `nil`).
    var hasResolvableUnit: Bool { exercise != nil || loop != nil || song != nil }

    /// A unit block whose referenced unit has gone missing (deleted → nullified). The
    /// player **skips** these rather than crashing (ADR 0066 R5). A `rest` is never
    /// orphaned (it carries no unit by design). Pure decision in `RoutineBudget`.
    var isOrphaned: Bool {
        RoutineBudget.isOrphaned(kind: kind, hasResolvableUnit: hasResolvableUnit)
    }

    /// Play order for a set of items (ADR 0066 R2) — sorted by explicit `order`, ties
    /// broken by `uid` for a stable result. Pure over the passed array (no relationship
    /// traversal), so it is testable on plain uninserted items.
    static func ordered(_ items: [RoutineItem]) -> [RoutineItem] {
        items.sorted { lhs, rhs in
            lhs.order == rhs.order ? lhs.uid.uuidString < rhs.uid.uuidString
                                   : lhs.order < rhs.order
        }
    }
}
