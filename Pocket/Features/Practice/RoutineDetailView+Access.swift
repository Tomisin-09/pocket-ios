import SwiftUI

/// The routine editor's **entitlement seam** (ADR 0112). Split into its own file to keep
/// `RoutineDetailView.swift` under the 400-line cap.
///
/// Routines are Pro, with one exception: the curated free-taste routine (`Routine.presetSlug`, the
/// seeded "Morning Routine") opens as a **demo** for a free player — they can look through it and
/// **rearrange** its blocks, but not add to it. The split is deliberate:
///
/// - *Reordering* a fixed set of curated blocks authors nothing. It exists so a free player can see
///   what a routine actually is, and feel the shape of one, before deciding to pay for their own.
/// - *Adding* is the authoring act, and it's also the load-bearing half of the gate: because a free
///   player can never add a block, the demo's contents stay exactly the ones we curated — all
///   free-tier or free-taste — so editing it can't become a way to assemble and run Pro drills.
///
/// Deletion is barred in the demo too, which is *not* about entitlement: the curated routines seed
/// exactly once ever ("deleted stays deleted"), so a free player who emptied the demo could never
/// rebuild it — they can't add blocks back. Rearranging shouldn't be able to destroy the one routine
/// they're allowed to run.
extension RoutineDetailView {
    /// Whether this routine is the curated free-taste demo.
    var isFreeTasteDemo: Bool {
        AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug)
    }

    /// Whether the block-adding affordances (add unit / insert rest, empty-routine hint) show. True
    /// in edit mode **and** on a provisional generated session (`!existsInStore`) — a generated
    /// session is reviewed before it's kept, so it's editable without an explicit Edit tap — and
    /// **always false for a free player**, who may reorder the demo but never extend it.
    var canAddBlocks: Bool {
        (isEditing || !existsInStore) && AccessPolicy.canAddRoutineUnits(isPro: isPro)
    }

    /// Whether swipe-to-delete is offered on a block. Off in the free demo (see the type comment) —
    /// otherwise it tracks edit mode / provisional review as before.
    var canDeleteBlocks: Bool {
        (isEditing || !existsInStore) && AccessPolicy.canAddRoutineUnits(isPro: isPro)
    }

    /// `.onDelete` takes an optional handler; passing `nil` removes the affordance entirely. Spelled
    /// as an explicitly-typed property because the ternary is ambiguous inline in a `ViewBuilder`.
    var blockDeleteAction: ((IndexSet) -> Void)? {
        guard canDeleteBlocks else { return nil }
        return { offsets in delete(offsets) }
    }

    /// Whether to explain the demo's limit — a free player inside the curated routine, in edit mode.
    var showsDemoFooter: Bool { !isPro && isFreeTasteDemo && isEditing }

    /// The footer shown to a free player inside the demo, naming the limit rather than leaving a
    /// missing Add button to be puzzled over.
    @ViewBuilder
    var demoFooter: some View {
        if showsDemoFooter {
            Text(Self.demoFooterText)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    static let demoFooterText = """
        Reorder these blocks to see how a routine fits together. Building your own routines is part \
        of Red Moon Pro.
        """
}
