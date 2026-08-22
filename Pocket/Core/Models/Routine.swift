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

    /// A manual **favourite** pin (ADR 0119) — the player's explicit "keep this close," surfaced by the
    /// Routines library's Favourites filter (a "show only starred" toggle). A pin, never a grade
    /// (ADR 0070): it feeds no algorithm, only where the routine is shown. A plain `Bool` with a
    /// declaration default so SwiftData lightweight migration fills pre-0119 routines with `false`
    /// — additive, no store wipe (CoreData 134110 rule).
    var isFavorite: Bool = false

    /// **Provenance**: the stable slug of the curated starter routine this was seeded from (ADR 0112,
    /// e.g. `"morning-warm-up"`) — `nil` for a user-built routine. Mirrors `Exercise.presetSlug`
    /// exactly: a plain optional `String`, not an enum, so the add is a **lightweight, non-lossy**
    /// migration (rows saved before this field decode to `nil` — CoreData 134110 rule, ADR 0012/0036).
    ///
    /// It records *where the routine came from*, never a Pro flag — access stays computed live from
    /// `isPro` (ADR 0112 "gate at read time"). It has **no monetization use since ADR 0144**: the
    /// free-taste run allowance it fed (`AccessPolicy.isFreeTasteRoutine`) is retired and its
    /// allowlist is empty, so the seeded routine is now simply trial content. **Never** filter it in a
    /// `#Predicate` (`presetSlug != nil` starves the main thread — the optional-predicate freeze);
    /// read it per-object in memory at the gate.
    var presetSlug: String?

    /// The ordered blocks. **Cascade-owned**: deleting the routine deletes its items (but
    /// never the units those items *reference* — that link nullifies, see `RoutineItem`).
    /// Declaration default keeps SwiftData lightweight migration additive (CoreData 134110).
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    var items: [RoutineItem] = []

    /// Items in play order. `@Relationship` arrays are not a dependable ordering, so the
    /// order is read off the explicit `RoutineItem.order` (ADR 0066 R2), the same
    /// discipline as `Song.loopsByStart`.
    var orderedItems: [RoutineItem] { RoutineItem.ordered(items) }

    /// Free-text **description**: what this session is *for* (ADR 0177). "Ten minutes before a
    /// lesson", "the bits of the Berklee week 3 sheet that actually needed work".
    ///
    /// The routine was the last practice unit with no prose of its own — `Exercise.notes` and
    /// `Song.comment` have always existed, and ADR 0167's `references` gave a routine somewhere to
    /// say *where it came from* without giving it anywhere to say *what it is for*. Named `notes` to
    /// mirror `Exercise.notes` exactly (the surface calls it **Description**, as the exercise's does).
    ///
    /// A **plain `String` with a declaration default**, not an optional: the field means "the prose,
    /// possibly none", and `""` says that as well as `nil` does while sparing every reader an
    /// unwrap. That is `Exercise.notes`' shape and the CoreData 134110 rule's requirement in one —
    /// additive, so lightweight migration fills every existing routine with `""` and no store is
    /// wiped. Trimmed at the commit sites, never on read.
    var notes: String = ""

    /// Where this session came from (ADR 0167) — a course's week 3, a teacher's assignment. **The
    /// most on-thesis owner of the four**: a course belongs to a sitting, not to a single drill,
    /// and it is the half of this feature nobody else models. Since ADR 0177 it is no longer the
    /// only prose a routine carries: `notes` says what the session is *for*, this says where it
    /// came *from*, and the two are deliberately separate fields.
    /// **`.cascade` like `items`.** Additive (CoreData 134110 rule).
    @Relationship(deleteRule: .cascade, inverse: \ReferenceLink.routine)
    var references: [ReferenceLink] = []

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

    /// How many times the player runs this block back-to-back before advancing (R3). Additive with
    /// a `1` default so SwiftData lightweight migration is safe (CoreData 134110). Only meaningful
    /// on a unit-bearing block — a `rest` carries no run to repeat. Read via `effectiveReps`.
    var reps: Int = 1

    /// The minutes a **generated** session allotted this block (ADR 0129), or `nil` for a
    /// hand-authored one that was never sized by a planner.
    ///
    /// The block model computes a share — a 15-minute block divided among the items it holds — and
    /// until now that number died at materialisation: `PracticePlanner.item(for:)` read a block's
    /// `unit` and `kind` and dropped its `minutes`. Persisting it is what lets a run **fit its ramp to
    /// its slot** (`SessionEstimate.fitted`) instead of playing whatever length the exercise happens
    /// to imply. It is a property of *this block in this routine*, never of the exercise — which is
    /// exactly why it lives here and not on `Exercise` (ADR 0129 sub-decision 3: generating a session
    /// must not rewrite an authored recipe).
    ///
    /// Optional with **no declaration default**, the migration-exempt shape used by
    /// `Exercise.targetTempoOverride` — pre-existing items migrate to `nil` and keep their natural
    /// length.
    var plannedMinutes: Int?

    /// Whether this block **declines the session's fit** and runs its unit's own authored recipe
    /// (ADR 0130). `false` — the default — leaves ADR 0129's behaviour exactly as it was.
    ///
    /// A flag rather than a cleared `plannedMinutes`, deliberately. Clearing the minutes would say the
    /// same thing to every consumer (they all read `nil` as "run as authored"), but it is a **one-way
    /// door**: the allotment is the only record of what the session asked for, so discarding it means
    /// the toggle can never come back and the block preview can no longer name both numbers. Keeping
    /// both makes the control reversible.
    ///
    /// Declaration default `false` → additive lightweight migration, no store wipe (CoreData 134110).
    var usesAuthoredLength: Bool = false

    /// The minutes that actually govern this block — the allotment unless the player declined it
    /// (ADR 0130). **The one expression** the run, the block preview and the session estimate read, so
    /// a decline cannot take effect on one surface and not another.
    var effectivePlannedMinutes: Int? { usesAuthoredLength ? nil : plannedMinutes }

    /// The minutes this block **actually runs for** — `effectivePlannedMinutes` for anything with a
    /// ramp, and ADR 0141's three-way rule for a block without one (ear, improvise).
    ///
    /// The two rules differ in what a `nil` allotment means. For a ramp block it means "play the
    /// unit's own recipe", which is a real length. For a ramp-less block there is no recipe to fall
    /// back on, so `nil` has to be split: a block that **declined** the fit runs open-ended, while a
    /// block no session ever sized takes its mode's default. `effectivePlannedMinutes` folds those
    /// together, which is why the resolution lives here rather than at each reader — the session
    /// player and the routine's own length estimate must not answer this differently.
    var resolvedBlockMinutes: Int? {
        guard loop != nil, loopRunMode != .trainer else { return effectivePlannedMinutes }
        return RampLessBlockLength.minutes(
            plannedMinutes: plannedMinutes,
            usesAuthoredLength: usesAuthoredLength,
            fallback: RampLessBlockLength.defaultMinutes(for: loopRunMode))
    }

    /// Backing storage for `loopRunMode` — a plain `String`, **not** the enum (the SwiftData
    /// enum-attribute migration rule; see `kindRaw`). Only meaningful on a **loop** block; ignored
    /// elsewhere. Declaration default = `.trainer` so every loop block saved before ADR 0104 Slice 2
    /// migrates to the standard trainer with no store wipe (CoreData 134110).
    var loopRunModeRaw: String = LoopRunMode.default.rawValue

    /// Typed view over `loopRunModeRaw` — whether a loop block runs the standard trainer or ear
    /// training (ADR 0104). Unrecognised/empty reads as `.trainer`. Meaningless on non-loop blocks.
    var loopRunMode: LoopRunMode {
        get { LoopRunMode(raw: loopRunModeRaw) }
        set { loopRunModeRaw = newValue.rawValue }
    }

    /// `reps` clamped to at least one run — the count the player and the session estimate use.
    var effectiveReps: Int { max(1, reps) }

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

    /// An **ear-training** block on a loop (ADR 0104 Slice 2) — the same `Loop`, run ears-only.
    ///
    /// Defaults to `warmup`, which claims it is not deliberate drilling and so doesn't count against
    /// the budget (ADR 0014 R1). It no longer claims the block has no *length*: ADR 0141 gives every
    /// ramp-less block a planned length, and the two are different questions — the kind is about
    /// intent, the length is about time.
    static func earLoopItem(_ loop: Loop, kind: RoutineItemKind = .warmup,
                            order: Int = 0) -> RoutineItem {
        let routineItem = RoutineItem(kind: kind, order: order)
        routineItem.loop = loop
        routineItem.loopRunMode = .ear
        return routineItem
    }

    /// An **improvise** block on a loop (ADR 0135 Slice 2) — the same `Loop`, run as a backing track
    /// to solo over.
    ///
    /// Defaults to `play`, per ADR 0135 B6a: a jam is a run-through, not deliberate drilling, so it is
    /// surfaced and unbudgeted. B6a's *rationale* — that it has no defined length — is amended by ADR
    /// 0141; its placement stands.
    static func improviseLoopItem(_ loop: Loop, kind: RoutineItemKind = .play,
                                  order: Int = 0) -> RoutineItem {
        let routineItem = RoutineItem(kind: kind, order: order)
        routineItem.loop = loop
        routineItem.loopRunMode = .improvise
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
