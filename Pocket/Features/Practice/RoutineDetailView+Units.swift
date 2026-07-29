import SwiftData
import SwiftUI

/// Adding and un-adding **unit blocks** from the picker (ADR 0066 slice 2; multi-add ADR 0127).
/// Split out of `RoutineDetailView` to keep that file under the 400-line cap.
///
/// Every adder re-resolves the picked unit into the editing sandbox by id first. The picker's
/// `@Query` hands back objects from the app's **main** context, and referencing one of those from
/// a sandboxed `RoutineItem` mixes contexts — the class of bug that surfaces as a save that
/// silently drops the link.
extension RoutineDetailView {
    /// Add the picked unit, or take back the block this picking session added for it (ADR 0127).
    ///
    /// The toggle is scoped to the **session**, not the routine: it removes only the block *this*
    /// sheet created, never one added earlier or on a previous visit. That's what lets a routine
    /// hold the same drill twice (a warm-up pass and a focused pass are a legitimate shape) while
    /// still giving a mis-tap an obvious way back.
    func toggleUnit(_ pick: RoutineUnitPick) {
        let key = pick.pickID
        if let uid = addedPickIDs.removeValue(forKey: key) {
            if let item = routine.items.first(where: { $0.uid == uid }) {
                editContext.delete(item)
                renumberBlocks()
            }
        } else if let item = block(for: pick) {
            insert(item)
            addedPickIDs[key] = item.uid
        }
    }

    /// Build the block for a pick, with the unit resolved into the sandbox. `nil` when the unit
    /// can't be resolved there — nothing is added rather than a block pointing at a foreign object.
    private func block(for pick: RoutineUnitPick) -> RoutineItem? {
        switch pick {
        case .exercise(let picked):
            guard let local = local(picked) else { return nil }
            return .item(local, order: nextOrder)
        case .loop(let picked):
            guard let local = local(picked) else { return nil }
            return .item(local, order: nextOrder)
        case .earLoop(let picked):
            // The same loop, run ears-only (ADR 0104 Slice 2).
            guard let local = local(picked) else { return nil }
            return .earLoopItem(local, order: nextOrder)
        case .song(let picked):
            guard let local = local(picked) else { return nil }
            return .item(local, order: nextOrder)
        }
    }

    /// Re-resolve a model from the app context into this view's editing sandbox by id.
    private func local<Model: PersistentModel>(_ model: Model) -> Model? {
        editContext.model(for: model.persistentModelID) as? Model
    }
}
