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
    /// Hang an existing row on this owner: attaching a row kept for later (ADR 0264 D5). Only
    /// `ReferenceLinkStore.attach` calls it, and only on a row with no owner, so it has at most one.
    func hold(_ link: ReferenceLink)
    /// What the References section calls this owner in its footer, in the player's words.
    var referenceOwnerNoun: String { get }
    /// The kinds of link the footer names first, as examples. A requirement, so a song's own wins.
    var referenceExamples: String { get }
}

extension ReferenceLinkOwner {
    /// Links in the player's order (ADR 0167) — the explicit `order` field, never the array's.
    var referencesInOrder: [ReferenceLink] { ReferenceLink.ordered(references) }

    var referenceExamples: String { "A lesson, a tab page, a teacher's write-up" }

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

    /// Apply a list-edit move to `owner`'s links and renumber.
    static func move(from offsets: IndexSet, to destination: Int, in owner: some ReferenceLinkOwner) {
        var ordered = owner.referencesInOrder
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, link) in ordered.enumerated() where link.order != index { link.order = index }
    }

    // MARK: - Remove and delete (ADR 0264 D11, D5)

    /// **Remove**, the owner section's hold and swipe (D11): take `links` off `owner` without losing
    /// what the player kept. Each one is decided by `ReferenceRemoval`, one at a time, so a second
    /// row of the same link sees the first one's outcome.
    ///
    /// A row this context inserted and never saved goes outright, file and all. That is the routine
    /// editor, which holds every change until **Save** (0167 phase 1, constraint 3): a link added and
    /// removed in one edit was never kept, and leaving it in *Not filed* would keep it anyway.
    static func remove(_ links: [ReferenceLink],
                       from owner: some ReferenceLinkOwner,
                       in context: ModelContext,
                       _ fileManager: FileManager = .default) {
        let unsaved = Set(context.insertedModelsArray.compactMap { ($0 as? ReferenceLink)?.uid })
        var others = (try? context.fetch(FetchDescriptor<ReferenceLink>())) ?? []
        for link in links {
            others.removeAll { $0.uid == link.uid }
            if unsaved.contains(link.uid) {
                deleteRows([link], in: context, fileManager)
                continue
            }
            switch ReferenceRemoval.decide(for: link, among: others) {
            case .unfile:
                // Not handed back to `others`: a row kept for later is never somewhere else.
                unfile(link)
            case .delete:
                // The row only. A file's bytes stay: the row filed elsewhere names the same file.
                context.delete(link)
            }
        }
        let gone = Set(links.map(\.uid))
        ReferenceLink.renumber(owner.references.filter { !gone.contains($0.uid) })
    }

    /// **Delete**, from the source's screen (D5): every row of `source` goes, with its file. The one
    /// place a source leaves Red Moon for good, and the screen confirms first, naming every place.
    static func delete(_ source: ReferenceSource,
                       in context: ModelContext,
                       _ fileManager: FileManager = .default) {
        let owners = source.rows.compactMap(\.owner)
        let gone = Set(source.rows.map(\.uid))
        deleteRows(source.rows, in: context, fileManager)
        for owner in owners {
            ReferenceLink.renumber(owner.references.filter { !gone.contains($0.uid) })
        }
    }

    /// Keep `link` for later (D1): no owner, so it lives in *Not filed*. Its `order` means nothing
    /// without an owner's list, so it goes back to zero.
    private static func unfile(_ link: ReferenceLink) {
        link.exercise = nil
        link.song = nil
        link.loop = nil
        link.routine = nil
        link.order = 0
    }

    /// Rows and their files. **An attachment's bytes go with its last row**: space comes back when the
    /// player deletes the file, not the next time they visit Settings. A file attached in two places is
    /// one file named by two rows (D3), so it stays while any row not being deleted names it.
    ///
    /// When the store can't be read to check, the bytes stay: a file nobody names is what
    /// `ReferenceAttachmentStore.orphanedFiles` and *Reclaim space* (ADR 0182) clear, while a file
    /// deleted from under another place can't be put back. The file's delete is swallowed, as
    /// `SongDeletion`'s is: a row the player asked to delete must go whether or not its file could be
    /// reached.
    private static func deleteRows(_ rows: [ReferenceLink], in context: ModelContext, _ fileManager: FileManager) {
        let gone = Set(rows.map(\.uid))
        let files = Set(rows.filter(\.isAttachment).map(\.attachmentFileName))
        if !files.isEmpty, let all = try? context.fetch(FetchDescriptor<ReferenceLink>()) {
            let stillNamed = Set(all.filter { !gone.contains($0.uid) }.map(\.attachmentFileName))
            for file in files where !stillNamed.contains(file) {
                try? ReferenceAttachmentStore.delete(fileName: file, fileManager)
            }
        }
        for row in rows { context.delete(row) }
    }
}

/// What **Remove** does to one row on an owner's References section (ADR 0264 D11). Values in, a
/// verdict out, so the rule is a test rather than a tap.
enum ReferenceRemoval: Equatable {
    /// The source is used nowhere else: the row moves to *Not filed*, note and file intact.
    case unfile
    /// The same link or file is filed somewhere else: this use goes, and its note with it. The source
    /// stays in the library through its other places, and a file's bytes stay with them.
    case delete

    /// `others` is every other row in the library. The same source is the same `sourceKey` (D3): one
    /// address, or one file on disk. Only a row that is **filed** counts as somewhere else; one kept
    /// for later is not a place.
    static func decide(for link: ReferenceLink, among others: [ReferenceLink]) -> ReferenceRemoval {
        let usedElsewhere = others.contains { other in
            other.uid != link.uid && other.isFiled && other.sourceKey == link.sourceKey
        }
        return usedElsewhere ? .delete : .unfile
    }
}

/// **Keep for later** as a place to add to (ADR 0264 D1): the References library's **＋** hands this to
/// the same editor and pickers an owner's section uses, and what they add has no owner.
///
/// It has no list of its own, so `references` is empty. Two things follow, both intended: a new row's
/// `order` is 0, which nothing reads without an owner, and the five-file cap
/// (`ReferenceAttachmentStore.maxPerOwner`) never applies. That cap is per exercise, song, loop or
/// routine, and the library is none of those.
final class KeepForLater: ReferenceLinkOwner {
    var references: [ReferenceLink] { [] }
    func makeReference() -> ReferenceLink { ReferenceLink() }
    /// Nothing to hang it on: a row kept for later is one with no owner.
    func hold(_ link: ReferenceLink) {}
    var referenceOwnerNoun: String { "reference" }
}

extension ReferenceLink {
    /// The owner holding this row, as the shape every References section reads. `nil` when kept for
    /// later.
    var owner: (any ReferenceLinkOwner)? {
        if let exercise { return exercise }
        if let song { return song }
        if let loop { return loop }
        if let routine { return routine }
        return nil
    }
}

// MARK: - Conformances

extension Exercise: ReferenceLinkOwner {
    func makeReference() -> ReferenceLink { ReferenceLink(exercise: self) }
    func hold(_ link: ReferenceLink) { link.exercise = self }
    var referenceOwnerNoun: String { "exercise" }
}

extension Song: ReferenceLinkOwner {
    func makeReference() -> ReferenceLink { ReferenceLink(song: self) }
    func hold(_ link: ReferenceLink) { link.song = self }
    var referenceOwnerNoun: String { "song" }
    /// The artist's own pages belong with the song, and saying so costs one clause rather than a
    /// field of their own (Tomisin, 2026-10-03: the cheaper of the two ways to hold them).
    var referenceExamples: String { "A lesson, a tab page, the artist's Instagram or YouTube" }

    /// How many references deleting this song leaves in the library (ADR 0264 D2): its own, and its
    /// loops', since the loops go with it and theirs stay too.
    var referencesLeftByDelete: Int {
        references.count + loops.reduce(0) { $0 + $1.references.count }
    }
}

extension Loop: ReferenceLinkOwner {
    func makeReference() -> ReferenceLink { ReferenceLink(loop: self) }
    func hold(_ link: ReferenceLink) { link.loop = self }
    var referenceOwnerNoun: String { "loop" }
}

extension Routine: ReferenceLinkOwner {
    func makeReference() -> ReferenceLink { ReferenceLink(routine: self) }
    func hold(_ link: ReferenceLink) { link.routine = self }
    var referenceOwnerNoun: String { "routine" }
}
