import Foundation

/// **Where one save from *Save to Red Moon* lands** (ADR 0264 D9), decided again by the app when it
/// drains the inbox, because the snapshot the extension picked from may be out of date. Values in, a
/// verdict out, so each rule is a test, as `PlanAccess` is.
///
/// **Nothing is dropped.** A save whose place has gone, has filled up, or is out of the player's reach
/// is kept for later instead, in *Not filed*, where the player can attach it themselves.
enum ShareInboxPlan: Equatable, Sendable {
    /// On the place it was saved to, by `ReferenceDestination.id`.
    case place(String)
    /// In *Not filed*: chosen so, or the place can't take it any more.
    case keepForLater

    /// The place a save names, as the app finds it now.
    struct Target: Equatable, Sendable {
        let kind: ReferencePlaceKind
        /// Whether it can take another file (`ReferenceAttachmentStore.maxPerOwner`). A link never
        /// fills a place.
        let canTakeFile: Bool
    }

    /// `target` is `nil` when the place named is gone: deleted since the snapshot was written.
    static func filing(for item: ShareInboxItem, target: Target?, standing: PlanStanding) -> ShareInboxPlan {
        guard let key = item.destination, let target else { return .keepForLater }
        // D6: never bought, a drill or routine isn't offered. A snapshot can only be stale in the other
        // direction, but the store is the authority.
        guard ReferenceAttachRules.offer(target.kind, for: standing) != .hidden else { return .keepForLater }
        guard !item.isFile || target.canTakeFile else { return .keepForLater }
        return .place(key)
    }
}
