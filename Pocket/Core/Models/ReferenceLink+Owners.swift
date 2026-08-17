import Foundation
import SwiftData

/// The four owners of a `ReferenceLink` (ADR 0167), given one shared shape so every References
/// section reads and mutates its links the same way — and so `Exercise.swift`, `Song.swift`,
/// `Loop.swift` and `Routine.swift` stay under the 400-line cap. Mirrors `Recording+Owners.swift`.
///
/// Reading `references` inside these accessors tracks the SwiftData relationship, so a section
/// refreshes when a link is added or deleted.
protocol ReferenceLinkOwner: AnyObject {
    /// The raw relationship. Order is not dependable here — read `referencesInOrder`.
    var references: [ReferenceLink] { get }
    /// A fresh, unsaved link already pointed at this owner. The caller fills in title and URL.
    func makeReference() -> ReferenceLink
    /// What the References section calls this owner in its footer, in the player's words.
    var referenceOwnerNoun: String { get }
}

extension ReferenceLinkOwner {
    /// Links in the player's order (ADR 0167) — the explicit `order` field, never the array's.
    var referencesInOrder: [ReferenceLink] { ReferenceLink.ordered(references) }

    /// Whether this owner has anything to show. Cheap enough to read in a `body`.
    var hasReferences: Bool { !references.isEmpty }
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
    @discardableResult
    static func add(title: String,
                    url raw: String,
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
        link.urlString = destination.absoluteString
        link.order = order
        context.insert(link)
        return link
    }

    /// Re-point an existing link. Same gate as `add`: a rejected string leaves the link untouched
    /// and reports `false`, rather than half-applying the edit.
    @discardableResult
    static func update(_ link: ReferenceLink, title: String, url raw: String) -> Bool {
        guard let destination = ReferenceURL.normalised(raw) else { return false }
        link.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        link.urlString = destination.absoluteString
        return true
    }

    /// Remove `links` from `owner` and close the gaps in `order`.
    static func delete(_ links: [ReferenceLink],
                       from owner: some ReferenceLinkOwner,
                       in context: ModelContext) {
        let doomed = Set(links.map(\.uid))
        for link in links { context.delete(link) }
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
