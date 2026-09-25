import Foundation
import SwiftData

/// A unit that can be put into — or taken back out of — a routine (ADR 0127). One value carries all
/// four bucket types so every surface that adds a block has a single seam, and `pickID` is the
/// **one** definition of a pick's identity: a picker keys its "added" checkmarks on it and the host
/// keys the block it created on the same string, so the two can never drift.
///
/// Two surfaces add blocks through it: the routine editor's `AddRoutineUnitSheet`, from inside a
/// routine, and `AddToRoutineSheet`, from a drill's or loop's own row (ADR 0222). `block(order:)` is
/// why that is safe — which factory a pick maps to is written once, so a loop added as ear training
/// from its library row is the same block the editor's Ear training bucket makes.
enum RoutineUnitPick {
    case exercise(Exercise)
    case loop(Loop)
    /// The same `Loop`, added as an ears-only block (ADR 0104 Slice 2) — a *different* pick from
    /// `.loop`, hence the prefixed id: both may sit in one routine.
    case earLoop(Loop)
    /// The same `Loop` again, added as an **improvise** block over it as a backing track (ADR 0135
    /// Slice 2). A third distinct pick on one unit, for the same reason as `.earLoop`.
    case improviseLoop(Loop)
    case song(Song)

    /// The pick for a loop run in `mode`. The one mapping from a `LoopRunMode` to a case, so a
    /// surface that offers the modes (the loop library's hold menu) can't pair a mode with the
    /// wrong block. Exhaustive with no `default`, like `LoopModeAccess.allows`: a fourth mode can't
    /// compile until it says what block it makes.
    static func loop(_ loop: Loop, as mode: LoopRunMode) -> RoutineUnitPick {
        switch mode {
        case .trainer: .loop(loop)
        case .ear: .earLoop(loop)
        case .improvise: .improviseLoop(loop)
        }
    }

    /// Stable per-row identity. A `Song` has no business `uid`; its import `sourceID` (a UUID
    /// string for local files) stands in, as it already does in the library lists.
    var pickID: String {
        switch self {
        case .exercise(let exercise): return exercise.uid.uuidString
        case .loop(let loop): return loop.uid.uuidString
        case .earLoop(let loop): return "ear-" + loop.uid.uuidString
        case .improviseLoop(let loop): return "improv-" + loop.uid.uuidString
        case .song(let song): return song.sourceID
        }
    }

    /// The block this pick makes, pointing at the unit it carries. The caller is responsible for
    /// that unit living in the same context the block is inserted into — see `resolved(in:)`.
    func block(order: Int) -> RoutineItem {
        switch self {
        case .exercise(let exercise): .item(exercise, order: order)
        case .loop(let loop): .item(loop, order: order)
        case .earLoop(let loop): .earLoopItem(loop, order: order)
        case .improviseLoop(let loop): .improviseLoopItem(loop, order: order)
        case .song(let song): .item(song, order: order)
        }
    }

    /// Whether `item` is a block this pick would have made — same unit, and for a loop the same
    /// mode, because a routine holding a loop as ear training does not hold it as a ramp.
    func matches(_ item: RoutineItem) -> Bool {
        switch self {
        case .exercise(let exercise): item.exercise?.uid == exercise.uid
        case .loop(let loop): item.loop?.uid == loop.uid && item.loopRunMode == .trainer
        case .earLoop(let loop): item.loop?.uid == loop.uid && item.loopRunMode == .ear
        case .improviseLoop(let loop): item.loop?.uid == loop.uid && item.loopRunMode == .improvise
        case .song(let song): item.song?.sourceID == song.sourceID
        }
    }

    /// The same pick with its unit re-resolved into `context` by id, or `nil` when it can't be.
    ///
    /// A picker's `@Query` hands back objects from the app's **main** context, and pointing a block
    /// in a sandbox at one of those mixes contexts — the class of bug that surfaces as a save that
    /// silently drops the link. `nil` means nothing is added rather than a block pointing at a
    /// foreign object.
    func resolved(in context: ModelContext) -> RoutineUnitPick? {
        func local<Model: PersistentModel>(_ model: Model) -> Model? {
            context.model(for: model.persistentModelID) as? Model
        }
        switch self {
        case .exercise(let exercise): return local(exercise).map { .exercise($0) }
        case .loop(let loop): return local(loop).map { .loop($0) }
        case .earLoop(let loop): return local(loop).map { .earLoop($0) }
        case .improviseLoop(let loop): return local(loop).map { .improviseLoop($0) }
        case .song(let song): return local(song).map { .song($0) }
        }
    }
}

extension Routine {
    /// Append the block `pick` makes as this routine's **last** (ADR 0222), and return it so the
    /// caller can take it back. `context` must be the one this routine and the pick's unit live in —
    /// the add-from-a-row sheet works in the main context throughout, so nothing needs resolving.
    @discardableResult
    func append(_ pick: RoutineUnitPick, in context: ModelContext) -> RoutineItem {
        let item = pick.block(order: nextOrder)
        item.routine = self
        context.insert(item)
        return item
    }

    /// Take one block back out by `uid` and close the gap it leaves. `false` when the routine holds
    /// no such block — already removed some other way, which is not an error worth surfacing.
    ///
    /// Out of the relationship **before** the delete, so the renumber never counts a block that is
    /// only marked for deletion and would otherwise leave a hole in `order` until the next save.
    @discardableResult
    func removeItem(_ uid: UUID, in context: ModelContext) -> Bool {
        guard let item = items.first(where: { $0.uid == uid }) else { return false }
        items.removeAll { $0.uid == uid }
        context.delete(item)
        renumberItems()
        return true
    }
}
