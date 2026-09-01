import Foundation
import SwiftData
import UniformTypeIdentifiers

/// The four owners of a `ReferenceLink` (ADR 0167), given one shared shape so every References
/// section reads and mutates its links the same way — and so `Exercise.swift`, `Song.swift`,
/// `Loop.swift` and `Routine.swift` stay under the 400-line cap. Mirrors `Recording+Owners.swift`.
///
/// Reading `references` inside these accessors tracks the SwiftData relationship, so a section
/// refreshes when a link is added or deleted.
protocol ReferenceLinkOwner: AnyObject {
    /// The raw relationship. Order is not dependable here — read `referencesInOrder`.
    var references: [ReferenceLink] { get }
    /// A fresh, unsaved link already pointed at this owner. The caller fills in the rest.
    func makeReference() -> ReferenceLink
    /// What the References section calls this owner in its footer, in the player's words.
    var referenceOwnerNoun: String { get }
}

extension ReferenceLinkOwner {
    /// Links in the player's order (ADR 0167) — the explicit `order` field, never the array's.
    var referencesInOrder: [ReferenceLink] { ReferenceLink.ordered(references) }

    /// Whether this owner has anything to show. Cheap enough to read in a `body`.
    var hasReferences: Bool { !references.isEmpty }

    /// How many of this owner's references are files we hold. Counted rather than stored: a count
    /// kept on the owner would be a second source of truth that a cascade could not update.
    var attachmentReferenceCount: Int { references.filter(\.isAttachment).count }

    /// Whether another file may be attached (ADR 0167 phase 2 —
    /// `ReferenceAttachmentStore.maxPerOwner`). Links are deliberately uncapped; see that constant
    /// for why the two differ.
    var canAddAttachment: Bool { attachmentReferenceCount < ReferenceAttachmentStore.maxPerOwner }
}

/// Insert, delete and reorder, in one place so the renumbering discipline cannot drift between the
/// five surfaces that host a section. Every mutation renumbers, so a delete never leaves a hole for
/// the next add to collide with.
enum ReferenceLinkStore {
    /// Attach a new link to `owner` at the end of its list.
    ///
    /// The URL is normalised through `ReferenceURL` first: this is the **single** save-time gate,
    /// so a caller cannot store a `javascript:` string by skipping a view's validation. Returns
    /// `nil` — inserting nothing — when the string is not one we accept.
    ///
    /// `note` is defaulted here and **deliberately not on `update`** — see that method.
    @discardableResult
    static func add(title: String,
                    url raw: String,
                    note: String = "",
                    to owner: some ReferenceLinkOwner,
                    in context: ModelContext) -> ReferenceLink? {
        guard let destination = ReferenceURL.normalised(raw) else { return nil }
        // Read the next order **before** minting the link. `makeReference()` sets the owner
        // relationship, and SwiftData populates the inverse straight away — so by the time the link
        // exists it is already in `owner.references`, carrying the declaration-default `order` of 0.
        // Measuring after would count the new link against itself and start the list at 1.
        let order = ReferenceLink.nextOrder(after: owner.references)
        let link = owner.makeReference()
        link.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        link.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        link.urlString = destination.absoluteString
        link.order = order
        context.insert(link)
        return link
    }

    /// Re-point an existing link. Same gate as `add`: a rejected string leaves the link untouched
    /// and reports `false`, rather than half-applying the edit — which is why the note is written
    /// *after* the guard, not before it.
    ///
    /// **`note` has no default here, and that asymmetry with `add` is deliberate.** A defaulted
    /// parameter would let an existing call site that never mentions the note silently erase one
    /// the player wrote. Adding a link cannot lose anything; correcting one can.
    @discardableResult
    static func update(_ link: ReferenceLink, title: String, url raw: String, note: String) -> Bool {
        guard let destination = ReferenceURL.normalised(raw) else { return false }
        link.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        link.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        link.urlString = destination.absoluteString
        return true
    }

    /// Attach a file to `owner` at the end of its list (ADR 0167 phase 2) — a picture, a PDF or a
    /// text file, decided by the bytes rather than by the caller.
    ///
    /// **The bytes are written before the row exists.** `ReferenceAttachmentStore.adopt` is the
    /// throwing half — it identifies, size-checks and (for images) re-encodes — so doing it first
    /// means a file that cannot be read leaves the store exactly as it was, rather than a row
    /// pointing at a file that was never written. The `uid` is minted here for the same reason: the
    /// file is named for it, so it has to exist before either the file or the link does.
    ///
    /// The cap is checked by the caller, not here: the control that adds is the thing that should be
    /// disabled, and a store call that silently no-ops would look like a bug from the outside. What
    /// *is* enforced here is the format, because this is the only way a file reaches the model.
    ///
    /// - Parameter contentType: what the picker claimed. A hint the store is free to overrule — see
    ///   `ReferenceAttachmentStore.adopt`.
    @discardableResult
    static func addAttachment(_ data: Data,
                              contentType: UTType? = nil,
                              title: String = "",
                              note: String = "",
                              to owner: some ReferenceLinkOwner,
                              in context: ModelContext,
                              _ fileManager: FileManager = .default) throws -> ReferenceLink {
        let uid = UUID()
        let stored = try ReferenceAttachmentStore.adopt(data, contentType: contentType, for: uid,
                                                        fileManager)
        // Same ordering trap as `add`: `makeReference()` wires the owner, and SwiftData fills the
        // inverse straight away, so the new link is already in `owner.references` at order 0.
        let order = ReferenceLink.nextOrder(after: owner.references)
        let link = owner.makeReference()
        link.uid = uid
        link.kind = stored.kind
        link.attachmentFileName = stored.fileName
        link.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        link.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        link.order = order
        context.insert(link)
        return link
    }

    /// Rename or re-note an attachment. There is no URL to gate, so unlike `update` this cannot fail
    /// — but `note` still takes no default, for the same reason it takes none there: correcting a
    /// reference must not be able to erase words the player wrote.
    static func updateAttachment(_ link: ReferenceLink, title: String, note: String) {
        link.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        link.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Remove `links` from `owner` and close the gaps in `order`.
    ///
    /// **An attachment's bytes go with its row**, on this path. They cannot go on every path: the owner
    /// inverses cascade (ADR 0167), and a SwiftData cascade deletes rows without running a line of
    /// ours — delete the exercise and these files are orphaned in place. That is what
    /// `ReferenceAttachmentStore.orphanedFiles` and *Reclaim space* (ADR 0182) exist for. Deleting here
    /// as well is not redundant: it is the difference between space coming back when the player
    /// deletes a picture and space coming back the next time they visit Settings.
    static func delete(_ links: [ReferenceLink],
                       from owner: some ReferenceLinkOwner,
                       in context: ModelContext,
                       _ fileManager: FileManager = .default) {
        let doomed = Set(links.map(\.uid))
        for link in links {
            if link.isAttachment {
                // Swallowed like `SongDeletion`'s: a reference the player asked to remove must go
                // whether or not its file could be reached, and what is left behind is exactly what
                // the sweep is for.
                try? ReferenceAttachmentStore.delete(fileName: link.attachmentFileName, fileManager)
            }
            context.delete(link)
        }
        ReferenceLink.renumber(owner.references.filter { !doomed.contains($0.uid) })
    }

    /// Apply a list-edit move to `owner`'s links and renumber.
    static func move(from offsets: IndexSet, to destination: Int, in owner: some ReferenceLinkOwner) {
        var ordered = owner.referencesInOrder
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, link) in ordered.enumerated() where link.order != index { link.order = index }
    }
}

// MARK: - Conformances

extension Exercise: ReferenceLinkOwner {
    func makeReference() -> ReferenceLink { ReferenceLink(exercise: self) }
    var referenceOwnerNoun: String { "exercise" }
}

extension Song: ReferenceLinkOwner {
    func makeReference() -> ReferenceLink { ReferenceLink(song: self) }
    var referenceOwnerNoun: String { "song" }
}

extension Loop: ReferenceLinkOwner {
    func makeReference() -> ReferenceLink { ReferenceLink(loop: self) }
    var referenceOwnerNoun: String { "loop" }
}

extension Routine: ReferenceLinkOwner {
    func makeReference() -> ReferenceLink { ReferenceLink(routine: self) }
    var referenceOwnerNoun: String { "routine" }
}
