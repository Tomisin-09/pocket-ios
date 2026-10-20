import Foundation
import SwiftData

/// **What attaching a source to a place does** (ADR 0264 D5): *Attach to…* and *Start an exercise from
/// this* both end here. Values in, a verdict out, so the rule is a test rather than a tap.
enum ReferenceFiling: Equatable {
    /// This row moves onto the place, with its note and its file.
    case move(UUID)
    /// This row's name and link are copied onto the place as a new row with no note: each place keeps
    /// its own (D3), and the note on the row copied from was written about somewhere else.
    case copy(UUID)

    /// - A row **kept for later** moves: it was waiting to be filed, and its note goes with it. A
    ///   source with two such rows (D2's two deleted drills) moves its newest; the other stays kept.
    /// - A **file** filed somewhere moves too. A file is its own source (D3) and has no link to copy,
    ///   so it is in one place at a time, and *Attach to…* reads *Move to…*.
    /// - Otherwise the link is **copied**, and the source is used in one more place.
    static func decide(for source: ReferenceSource) -> ReferenceFiling {
        if let kept = source.keptForLater.first { return .move(kept.uid) }
        if source.isAttachment { return .move(source.newest.uid) }
        return .copy(source.newest.uid)
    }

    // MARK: - The source screen's words (D5)

    /// The picker's button, and its title.
    static func attachTitle(for source: ReferenceSource) -> String {
        if !source.isFiled { return "Attach to…" }
        return source.isAttachment ? "Move to…" : "Also attach to…"
    }

    /// The picker's title: the button that opened it, without its ellipsis.
    static func pickerTitle(for source: ReferenceSource) -> String {
        attachTitle(for: source).trimmingCharacters(in: CharacterSet(charactersIn: "…"))
    }

    /// The new-exercise button, or `nil` for a file that is filed: starting a drill from it would take
    /// it off the place it's on, which a button named *Start* shouldn't do.
    static func startTitle(for source: ReferenceSource) -> String? {
        if !source.isFiled { return "Start an exercise from this" }
        return source.isAttachment ? nil : "Start another exercise from this"
    }

    /// The caption under *Start an exercise from this*, while it is the screen's main action.
    static func startCaption(for source: ReferenceSource) -> String? {
        guard !source.isFiled else { return nil }
        let noun = source.isAttachment ? source.newest.kind.noun : ReferenceLinkKind.link.noun
        return "New exercise opens with this \(noun) already attached."
    }
}

extension ReferenceLinkStore {
    /// **Attach** `source` to `owner` (D5), moving or copying as `ReferenceFiling` decides. Returns the
    /// row now on `owner`, or `nil` when nothing was written: a row that has gone, or a link the store's
    /// gate no longer accepts.
    ///
    /// The picker never offers the place a row is already on, nor a full one to a file
    /// (`ReferenceDestinationPicker`); a move onto its own owner is still a no-op here, so a stale
    /// sheet can't renumber a list for nothing.
    @discardableResult
    static func attach(_ source: ReferenceSource,
                       to owner: some ReferenceLinkOwner,
                       in context: ModelContext) -> ReferenceLink? {
        switch ReferenceFiling.decide(for: source) {
        case .move(let uid):
            guard let row = source.rows.first(where: { $0.uid == uid }) else { return nil }
            let previous = row.owner
            if let previous, previous === owner { return row }
            // Read the order before the row is hung on `owner`: SwiftData fills the inverse straight
            // away, so measuring after would count the row against itself (`add` has the same trap).
            let order = ReferenceLink.nextOrder(after: owner.references)
            unfile(row)
            owner.hold(row)
            row.order = order
            if let previous { ReferenceLink.renumber(previous.references.filter { $0.uid != row.uid }) }
            return row
        case .copy(let uid):
            guard let row = source.rows.first(where: { $0.uid == uid }) else { return nil }
            return add(title: row.title, url: row.urlString, to: owner, in: context)
        }
    }

    /// Attach the source holding the row `uid`, read fresh from the store: *Start an exercise from
    /// this*, whose sheet is up long enough for the source to have changed since its button was tapped.
    @discardableResult
    static func attach(sourceContaining uid: UUID,
                       to owner: some ReferenceLinkOwner,
                       in context: ModelContext) -> ReferenceLink? {
        let links = (try? context.fetch(FetchDescriptor<ReferenceLink>())) ?? []
        guard let source = ReferenceLibrary.source(containing: uid, in: links) else { return nil }
        return attach(source, to: owner, in: context)
    }
}
