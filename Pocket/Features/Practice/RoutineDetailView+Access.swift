import SwiftUI

/// The routine editor's **entitlement seam**. Split into its own file to keep
/// `RoutineDetailView.swift` under the 400-line cap.
///
/// Routines are Pro, full stop (ADR 0144 D1). ADR 0112's **demo exception** — a free player could
/// open the curated "Morning Routine" and rearrange, though never extend, its blocks — went with the
/// rest of the free line, and with it the footer that explained why Add was missing. A player who
/// reaches this screen at all has already passed the Home wall and the routine gate, so these
/// properties now only answer the editing questions they were always really about: edit mode, and a
/// provisional generated session.
extension RoutineDetailView {
    /// Whether the block-adding affordances (add unit / insert rest, empty-routine hint) show. True
    /// in edit mode **and** on a provisional generated session (`!existsInStore`) — a generated
    /// session is reviewed before it's kept, so it's editable without an explicit Edit tap. The
    /// `AccessPolicy` call is kept as defence in depth behind ADR 0144 D4's wall: it re-locks
    /// correctly if a trial lapses with this screen open.
    var canAddBlocks: Bool {
        (isEditing || !existsInStore) && AccessPolicy.canAddRoutineUnits(isPro: isPro)
    }

    /// Whether swipe-to-delete is offered on a block — the same rule as `canAddBlocks`, since adding
    /// and removing are the same authoring act.
    var canDeleteBlocks: Bool {
        (isEditing || !existsInStore) && AccessPolicy.canAddRoutineUnits(isPro: isPro)
    }

    /// `.onDelete` takes an optional handler; passing `nil` removes the affordance entirely. Spelled
    /// as an explicitly-typed property because the ternary is ambiguous inline in a `ViewBuilder`.
    var blockDeleteAction: ((IndexSet) -> Void)? {
        guard canDeleteBlocks else { return nil }
        return { offsets in delete(offsets) }
    }

    /// The same optional-handler trick for **reorder** (ADR 0180 D3), gated by the same rule as
    /// delete — reordering and removing are the same authoring act, so they answer to one gate.
    ///
    /// `List` will drag-reorder a row on a long press whether or not `editMode` is active, so the
    /// unconditional `.onMove` this replaces left a **saved routine in read-only mode** rearrangeable
    /// by a hold that drifts — and silently, because there is no Cancel on that path to put it back
    /// and the sandbox commits the new `order` on the spot. The screen already promised otherwise:
    /// Edit is what unlocks the changes. Handing `nil` is what makes that promise true, and leaves
    /// reordering where its drag handles already are.
    ///
    /// A **provisional generated session** keeps the hold-drag, because it is `!existsInStore` and so
    /// passes the gate: that screen is a review, editable without an Edit tap, and it already swipes
    /// to delete on the same grounds.
    var blockMoveAction: ((IndexSet, Int) -> Void)? {
        guard canDeleteBlocks else { return nil }
        return { offsets, destination in move(from: offsets, to: destination) }
    }

    /// Drag-reorder writes the explicit `order` (ADR 0066 R2) so play order survives a fetch.
    private func move(from offsets: IndexSet, to destination: Int) {
        var ordered = routine.orderedItems
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in ordered.enumerated() { item.order = index }
        haptic(.light)
    }

    /// Delete the swiped blocks (offsets index the *displayed* ordered list), then renumber
    /// the survivors so `order` stays contiguous.
    func delete(_ offsets: IndexSet) {
        let ordered = routine.orderedItems
        for index in offsets { editContext.delete(ordered[index]) }
        renumberBlocks()
        haptic(.medium)
    }
}
