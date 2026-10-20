import Foundation
import SwiftData

/// **What attaching a source to a place does** (ADR 0264 D5): *Attach to…* and *Start an exercise from
/// this* both end here. Values in, a verdict out, so the rule is a test rather than a tap.
enum ReferenceFiling: Equatable {
    /// This row moves onto the place, with its note and its file.
    case move(UUID)
    /// This row's name and link, or its file, are copied onto the place as a new row with no note: each
    /// place keeps its own (D3), and the note on the row copied from was written about somewhere else.
    /// A file's copy names the same file on disk, so nothing is stored twice and the two rows are one
    /// source.
    case copy(UUID)

    /// - A row **kept for later** moves: it was waiting to be filed, and its note goes with it. A
    ///   source with two such rows (D2's two deleted drills) moves its newest; the other stays kept.
    /// - Otherwise it is **copied**, link or file, and the source is used in one more place.
    static func decide(for source: ReferenceSource) -> ReferenceFiling {
        if let kept = source.keptForLater.first { return .move(kept.uid) }
        return .copy(source.newest.uid)
    }

    // MARK: - The source screen's words (D5)

    /// The picker's button, and its title.
    static func attachTitle(for source: ReferenceSource) -> String {
        source.isFiled ? "Also attach to…" : "Attach to…"
    }

    /// The picker's title: the button that opened it, without its ellipsis.
    static func pickerTitle(for source: ReferenceSource) -> String {
        attachTitle(for: source).trimmingCharacters(in: CharacterSet(charactersIn: "…"))
    }

    /// The new-exercise button. Once filed, the new drill gets a copy and the places it's on keep theirs.
    static func startTitle(for source: ReferenceSource) -> String {
        source.isFiled ? "Start another exercise from this" : "Start an exercise from this"
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
    /// A file's copy is a second row naming the same file, not a second file: so it groups with the
    /// first (`ReferenceLink.sourceKey`), the source's screen shows both places, and a PDF of 25 MB
    /// isn't stored twice. Deleting either row leaves the bytes for the other (`deleteRows`).
    ///
    /// The picker never offers the place a row is already on, nor a full one to a file
    /// (`ReferenceDestinationPicker`), so neither is checked again here.
    @discardableResult
    static func attach(_ source: ReferenceSource,
                       to owner: some ReferenceLinkOwner,
                       in context: ModelContext) -> ReferenceLink? {
        switch ReferenceFiling.decide(for: source) {
        case .move(let uid):
            // Only a row kept for later moves (`decide`), so there is no place to take it off.
            guard let row = source.rows.first(where: { $0.uid == uid }) else { return nil }
            // Read the order before the row is hung on `owner`: SwiftData fills the inverse straight
            // away, so measuring after would count the row against itself (`add` has the same trap).
            let order = ReferenceLink.nextOrder(after: owner.references)
            owner.hold(row)
            row.order = order
            return row
        case .copy(let uid):
            guard let row = source.rows.first(where: { $0.uid == uid }) else { return nil }
            guard row.isAttachment else { return add(title: row.title, url: row.urlString, to: owner, in: context) }
            // Same ordering trap as `add`: `makeReference()` wires the owner, and the inverse fills at once.
            let order = ReferenceLink.nextOrder(after: owner.references)
            let copy = owner.makeReference()
            // The raw kind, so a kind only a newer build knows is copied as it was rather than as `.link`.
            copy.kindRaw = row.kindRaw
            copy.attachmentFileName = row.attachmentFileName
            copy.title = row.title
            copy.order = order
            context.insert(copy)
            return copy
        }
    }

    /// The source screen's **Edit** (D3): the name goes to every row of `source`, and a link's address
    /// with it, so it stays one source; the note goes to `row` alone, as each place keeps its own. A file
    /// is renamed, never re-pointed (ADR 0167 phase 2). Pass the source as it was before the edit, since
    /// a new address regroups the rows. `false`, writing nothing, when the store's gate refuses the
    /// address.
    @discardableResult
    static func edit(_ row: ReferenceLink, of source: ReferenceSource?,
                     title: String, url: String, note: String) -> Bool {
        let siblings = (source?.rows ?? []).filter { $0.uid != row.uid }
        if row.isAttachment {
            updateAttachment(row, title: title, note: note)
            for sibling in siblings { updateAttachment(sibling, title: title, note: sibling.note) }
            return true
        }
        guard update(row, title: title, url: url, note: note) else { return false }
        for sibling in siblings { update(sibling, title: title, url: url, note: sibling.note) }
        return true
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
