import Foundation
import SwiftData

/// What a reference link *is* — a pointer out of the app, stored as a `String` and never as a raw
/// enum attribute (`docs/swiftdata-gotchas.md`: a custom enum stored on a `@Model` migrates cleanly
/// in the simulator and traps on a device that has old data — ADR 0036 paid for that lesson).
///
/// `image` is carried from day one although ADR 0167 sequences images second. The field exists so
/// phase 2 is a **pure addition** rather than a retype after the schema freeze, which
/// `docs/backlog.md` records as now-or-never.
enum ReferenceLinkKind: String, CaseIterable {
    /// A URL the player typed or pasted — a lesson, a tab page, a course, a teacher's write-up.
    case link
    /// A picture of the source: a tab screenshot, a photo of a page, a diagram somebody drew you.
    case image
    /// A PDF — which is what a downloaded tab very often *is*. Stored whole and rendered by PDFKit,
    /// never flattened to a picture of page one: a six-page tab that silently lost five pages would
    /// be a worse feature than refusing PDFs.
    case pdf
    /// A plain-text file — ASCII tab, the format the internet taught guitarists in before anything
    /// else. Stored as bytes and rendered fixed-width without wrapping, because that is the only way
    /// it is readable at all.
    case text
    /// A Markdown file — somebody's written lesson notes. **A separate kind from `.text` on purpose,
    /// and the difference is how it is drawn:** `.txt` is a *grid* (tab only lines up fixed-width and
    /// unwrapped), Markdown is *prose* (it wraps, in a proportional font, with its emphasis
    /// rendered). Storing both as `.text` would have meant picking one treatment and being wrong
    /// about half the files.
    case markdown

    /// The kinds that are **a file on disk** rather than a pointer out of the app.
    static let attachmentKinds: [ReferenceLinkKind] = [.image, .pdf, .text, .markdown]

    /// The extension a stored file of this kind carries. Load-bearing: `filesOnDisk` recognises our
    /// own files by it during a sweep, and it is what makes an exported archive openable by hand.
    var fileExtension: String {
        switch self {
        case .link: return ""
        case .image: return "jpg"
        case .pdf: return "pdf"
        case .text: return "txt"
        case .markdown: return "md"
        }
    }

    /// What the app calls one of these in a sentence.
    /// The noun with a capital, for the places that name a kind on its own rather than mid-sentence
    /// — a row with no title of its own, and the file preview in the editor.
    var capitalizedNoun: String { noun.capitalizedFirst }

    var noun: String {
        switch self {
        case .link: return "link"
        case .image: return "picture"
        case .pdf: return "PDF"
        case .text: return "text file"
        case .markdown: return "Markdown file"
        }
    }
}

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
/// over a generic `ownerKind + ownerID` and `JournalEntry` follows: exactly one of `exercise`,
/// `song`, `loop`, `routine` is non-nil. A generic pair would move referential integrity out of
/// SwiftData and into hand-written lookups that cannot cascade.
///
/// ⚠ **The owner inverses cascade** — the opposite of notes and takes, and the first question a
/// reviewer asks. A note or a take nullifies (ADR 0151) because it is a record of *you*: a
/// reflection you wrote outlives the loop it was about. A reference link is a record of *the
/// owner* — it is a pointer to where **this exercise** came from, and it means nothing once the
/// exercise is gone. Delete the owner, delete the pointer.
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

    // MARK: - Owners (exactly one is non-nil)

    /// The exercise this came from — a drill built out of somebody's lesson.
    var exercise: Exercise?
    /// The song this came from — a transcription, a tab page, a cover breakdown.
    var song: Song?
    /// The loop this came from — the one passage a video actually explains.
    var loop: Loop?
    /// The routine this came from — a course's week 3. **The most on-thesis owner and the half
    /// nobody else models**: a course belongs to a session, not to a drill (ADR 0167).
    var routine: Routine?

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

private extension String {
    /// "picture" → "Picture". Only ever applied to the fixed nouns above, so there is no locale
    /// subtlety here that `localizedCapitalized` would handle better.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
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
