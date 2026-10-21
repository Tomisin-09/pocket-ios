import Foundation
import SwiftData

/// **Where you learned it** (ADR 0167): a source hung off the thing it explains — an exercise, a
/// song, a loop or a routine. A source is either a **URL** the player pasted (phase 1) or an
/// **image** they picked (phase 2); `kind` says which, and the two halves share this one row, one
/// order and one section rather than forking into parallel lists.
///
/// Pocket does not own the material and does not own the method. Somebody else is teaching the
/// thing, and the app's job is what happens between opening that resource and being able to play
/// it. Until this model existed that was a claim in `PROJECT.md` and nothing in the store: an
/// exercise built from a lesson came back a week later as a fretboard diagram with no provenance.
///
/// Follows the model discipline (ADR 0011/0036): a business `uid`, **declaration defaults** on
/// every non-optional attribute (the CoreData 134110 rule — `init`-only defaults wipe the store),
/// and any enum stored through a `String` backing field.
///
/// The owner is polymorphic through **typed optional relationships**, the shape ADR 0066 R4 chose
/// over a generic `ownerKind + ownerID` and `JournalEntry` follows: **at most one** of `exercise`,
/// `song`, `loop`, `routine` is non-nil (ADR 0264 D1). A reference with none is *kept for later*:
/// not filed yet, or left behind by an owner that was deleted. A generic pair would move
/// referential integrity out of SwiftData and into hand-written lookups.
///
/// **The owner inverses nullify** (ADR 0264 D2), as notes and takes do (ADR 0151). ADR 0167 had
/// them cascade, on the reasoning that a reference is a record of its owner. With a References
/// library it is a record of *where you learned something*, and that outlives the drill made from
/// it: deleting an owner leaves its references not filed, note and file intact.
///
/// **Never filter on this in a `#Predicate`.** Optional-relationship predicates starve the main
/// thread (`docs/swiftdata-gotchas.md`); fetch broadly and filter in memory.
@Model
final class ReferenceLink {
    /// Stable business id — list diffing / selection / undo, like `Loop`/`Exercise`/`Routine`.
    var uid: UUID

    /// What the player calls this source ("Signals Music Studio — CAGED part 2"). Typed by hand:
    /// nothing here fetches a page title, see `ReferenceURL`. Empty is allowed and renders as the
    /// host, because making the player name a link before they may save it is friction in front of
    /// the paste this feature exists for.
    var title: String = ""

    /// **What you took from it** — "the down-up bit starts about four minutes in", "only the chorus
    /// voicings are useful here". Distinct in job from `title`, and the distinction is the whole
    /// reason the field exists: the title says *what the resource is*, which you can reconstruct
    /// from the host a week later; the note says *what it gave you*, which you cannot.
    ///
    /// Plain non-optional `String` with a **declaration default**, the shape `Exercise.notes` and
    /// `Song.comment` already use — never `String?`, and never an `init`-only default (this file's
    /// header states the CoreData 134110 rule this obeys).
    var note: String = ""

    /// The destination, stored exactly as `ReferenceURL.normalised` produced it. Validated on save
    /// to `http`/`https`; opened with `openURL`, which adds no web view and no capability.
    var urlString: String = ""

    /// Position within its owner's list — the player's order, not a ranking (ADR 0070). Contiguous
    /// from zero after any add or delete.
    var order: Int = 0

    /// When the link was added. Not shown anywhere yet; kept so a later "recently added" read does
    /// not need a migration.
    var dateAdded: Date = Date.now

    /// `ReferenceLinkKind` through a `String` — see the type's note. Read `kind`, never this.
    var kindRaw: String = ReferenceLinkKind.link.rawValue

    /// The leaf filename of this reference's file in `Application Support/References/` — a picture, a
    /// PDF or a text file — or empty when it is a link (ADR 0167 phase 2). **The bytes are never
    /// stored here**: this is the `RecordingStore`/`SongFileStore` shape the ADR names, and not
    /// `@Attribute(.externalStorage)`, which appears nowhere in this codebase and is the wrong choice
    /// for the day sync lands.
    ///
    /// Plain non-optional `String` with a **declaration default**, like `note` above and for the same
    /// reason: an `init`-only default is the CoreData 134110 failure this file's discipline exists to
    /// prevent. Additive on a live table, which the schema freeze permits (`docs/backlog.md`) — and
    /// additive is the whole point of `kindRaw` having carried `.image` since day one.
    var attachmentFileName: String = ""

    // MARK: - Owners (at most one is non-nil; none means not filed, ADR 0264 D1)

    /// The exercise this came from — a drill built out of somebody's lesson.
    var exercise: Exercise?
    /// The song this came from — a transcription, a tab page, a cover breakdown.
    var song: Song?
    /// The loop this came from — the one passage a video actually explains.
    var loop: Loop?
    /// The routine this came from — a course's week 3. **The most on-thesis owner and the half
    /// nobody else models**: a course belongs to a session, not to a drill (ADR 0167).
    var routine: Routine?

    /// Whether any owner holds this reference. `false` is a state, not an error: the reference is
    /// kept for later (ADR 0264 D1), and the archive carries it on its own (D7).
    var isFiled: Bool { exercise != nil || song != nil || loop != nil || routine != nil }

    init(uid: UUID = UUID(),
         title: String = "",
         note: String = "",
         urlString: String = "",
         attachmentFileName: String = "",
         order: Int = 0,
         dateAdded: Date = .now,
         kind: ReferenceLinkKind = .link,
         exercise: Exercise? = nil,
         song: Song? = nil,
         loop: Loop? = nil,
         routine: Routine? = nil) {
        self.uid = uid
        self.title = title
        self.note = note
        self.urlString = urlString
        self.attachmentFileName = attachmentFileName
        self.order = order
        self.dateAdded = dateAdded
        self.kindRaw = kind.rawValue
        self.exercise = exercise
        self.song = song
        self.loop = loop
        self.routine = routine
    }
}

// MARK: - Derived

extension ReferenceLink {
    /// The stored `kindRaw` as its enum. An unrecognised string reads as `.link` rather than
    /// crashing — a store written by a newer build must stay openable by an older one.
    ///
    /// ⚠ **Do not use this to ask "is this a file?"** — use `isAttachment`. That fallback means a row
    /// written by a *newer* build, in a kind this build has never heard of, reads as `.link` while
    /// still carrying a filename; deciding on `kind` alone would send it to `openURL` with an empty
    /// address. `kind` answers *how do I render this*, and only that.
    var kind: ReferenceLinkKind {
        get { ReferenceLinkKind(rawValue: kindRaw) ?? .link }
        set { kindRaw = newValue.rawValue }
    }

    /// The site this points at, for the row's subtitle. `nil` if the stored string somehow is not a
    /// link we would accept today.
    var displayHost: String? { ReferenceURL.displayHost(urlString) }

    /// What the row's first line shows: the player's title, or the host when they saved without
    /// naming it, or the raw string as a last resort. Never empty, never "Untitled" — a link with
    /// no name is still a place, so we show the place.
    ///
    /// An **attachment** has no place to fall back to, so an unnamed one reads as its kind —
    /// "Picture", "PDF", "Text file". That word is also what VoiceOver says (ADR 0167 phase 2
    /// decision 4: the title *is* the alt text, and it is not required — a file you just picked
    /// should not need naming before it can be saved).
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if isAttachment { return kind.capitalizedNoun }
        return displayHost ?? urlString
    }

    /// The note as the row should show it, or `nil` when there is nothing to show. Trimmed *here*
    /// as well as at the store, so a link written by an older build — or by a test that set the
    /// property directly — can never render a third line made of whitespace.
    var displayNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The destination to hand `openURL`, or `nil` if it is no longer openable. Always `nil` for an
    /// attachment: nothing we store is openable *outside* the app, and handing a container file URL
    /// to `openURL` is how a row would quietly start doing something else.
    var destination: URL? {
        guard !isAttachment else { return nil }
        return ReferenceURL.normalised(urlString)
    }

    /// Whether this reference is a **file we hold** rather than a pointer out of the app.
    ///
    /// Keyed on the filename, deliberately **not** on `kind`. An unknown `kindRaw` — a row written by
    /// a newer build — falls back to `.link`, and a row that fell back while still carrying a file is
    /// exactly the case that must not be handed to `openURL`. The filename is the fact; the kind is
    /// the interpretation.
    var isAttachment: Bool { !attachmentFileName.isEmpty }
}

// MARK: - Ordering

extension ReferenceLink {
    /// Links in the player's order. `@Relationship` arrays are not a dependable ordering, so the
    /// order is read off the explicit `order` field — the same discipline as `Routine.orderedItems`
    /// and `Song.loopsByStart`. `uid` breaks ties so a list never jitters between reads.
    static func ordered(_ links: [ReferenceLink]) -> [ReferenceLink] {
        links.sorted { lhs, rhs in
            lhs.order == rhs.order ? lhs.uid.uuidString < rhs.uid.uuidString
                                   : lhs.order < rhs.order
        }
    }

    /// Renumber `links` contiguously from zero in their current order, so a delete never leaves a
    /// hole that the next add lands in. Call after every add, delete or move.
    static func renumber(_ links: [ReferenceLink]) {
        for (index, link) in ordered(links).enumerated() where link.order != index {
            link.order = index
        }
    }

    /// The `order` a new link should take to land at the end of `links`.
    static func nextOrder(after links: [ReferenceLink]) -> Int {
        (links.map(\.order).max() ?? -1) + 1
    }
}
