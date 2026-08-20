import Foundation
import SwiftData

/// A **practice take** — a mic-only audio-journal recording of the user's own playing (ADR 0069).
/// Unlike a `Song` (a security-scoped bookmark to a file *in place*, which the app doesn't own),
/// a take is an **app-authored** AAC file the app writes into its own container. The model carries
/// the metadata; the bytes live on disk, addressed by `fileName` through `RecordingStore`.
///
/// **Owner is polymorphic** (the `JournalEntry`/ADR 0058 pattern): at most one of
/// `loop`/`exercise`/`song` is set — the thing the take was recorded against — and `ownerKind`
/// derives from which. Each is the inverse of a **cascade** array on the parent
/// (`Loop`/`Exercise`/`Song`.`recordings`), so a take is owned by what it was recorded against and
/// deleting that owner deletes the take's row — mirroring the sibling `journal` pillar. Cascade
/// removes the row, not the on-disk file, so the now-unreferenced audio is reaped by
/// `RecordingStore`'s orphan sweep (the retention story). An inverse is required for the delete
/// rule to fire at all: a bare unidirectional relationship leaves `loop`/`exercise`/`song` dangling
/// at a deleted model instead of clearing.
///
/// The app **never** renders its own loop/song playback into this file — a take is the microphone
/// only, so every recording stays free of third-party rights (ADR 0001/0064). See ADR 0069 §5.
@Model
final class Recording {
    /// Stable business id — list diffing / `StableRef` presentation, like `Loop`/`Marker`
    /// (the SwiftData `persistentModelID` is unstable before insert). Also the basis of the
    /// on-disk `fileName`, so the row and its file share one identity.
    var uid: UUID

    /// When the take was recorded — takes list newest-first.
    var createdAt: Date

    /// Length of the take in seconds, measured at stop. `0` for a take that captured nothing.
    var duration: TimeInterval

    /// The player's own name for this take, or `nil` for one never named.
    ///
    /// Takes are the **only** journal row with nothing but a timestamp to tell them apart — a note
    /// carries its own words, a session carries its routine's name — which is why naming is offered
    /// here and nowhere else (device pass 2026-08-05). Additive optional with **no declaration
    /// default**, so lightweight migration is exempt from the mandatory-attribute rule.
    var title: String?

    /// What the player wrote about this take, or `nil` for one never annotated (ADR 0174).
    ///
    /// A take's own field, deliberately **not** a `JournalEntry` owned by the recording. A note here
    /// belongs to the audio the way a title does — it is read on the take's own screen, beside the
    /// thing it describes. The cost, accepted in 0174: it does not appear in the Journal feed and
    /// Journal search does not match it. Additive optional with **no declaration default**, so
    /// lightweight migration is exempt from the mandatory-attribute rule — the same shape as `title`.
    var note: String?

    /// The AAC file's name **relative** to the recordings directory (e.g. `"<uid>.m4a"`) — never
    /// an absolute path: the container URL changes across installs/restores, so only the leaf is
    /// stable. Resolve to a `URL` through `RecordingStore.url(for:)`.
    var fileName: String

    /// The loop this take was recorded against, or `nil`. Optional additive relationship — a new
    /// entity, so there are no pre-existing rows to migrate; nullifies if the loop is deleted.
    var loop: Loop?

    /// The exercise this take was recorded against, or `nil`. See `loop`.
    var exercise: Exercise?

    /// The song this take was recorded against, or `nil`. See `loop`.
    var song: Song?

    /// The owner's caption at capture time — "Don't Know Why Guitar Cover · Chords" — kept so a take
    /// that **outlives** its owner still says what it was recorded against (ADR 0151). The three
    /// relationships above nullify on the owner's deletion, and without this the surviving row would
    /// render as a bare "Take 0:11": the audio is the irreplaceable part, but a take you can't
    /// identify is barely worth keeping.
    ///
    /// Written once at capture through `JournalTimeline.ownerLabel(loop:exercise:song:)` — the same
    /// function that renders the live caption — so the fallback can't drift from what it replaces.
    /// Additive optional with **no declaration default**, so lightweight migration is exempt from the
    /// CoreData 134110 mandatory-attribute rule. `nil` for takes captured before this shipped.
    var ownerLabelAtTake: String?

    init(fileName: String, duration: TimeInterval, uid: UUID = UUID(), createdAt: Date = Date(),
         loop: Loop? = nil, exercise: Exercise? = nil, song: Song? = nil) {
        self.uid = uid
        self.createdAt = createdAt
        self.duration = duration
        self.fileName = fileName
        self.loop = loop
        self.exercise = exercise
        self.song = song
    }

    /// What a take was recorded against — derived from which owner relationship is set, so it can't
    /// drift from the stored links (no stored enum, dodging the SwiftData enum-attribute migration
    /// footgun — `docs/swiftdata-gotchas.md`). `loop` wins, then `exercise`, then `song`.
    enum OwnerKind: Equatable { case loop, exercise, song, none }

    /// The take's owner kind. Precedence is fixed so a stray double-set still resolves the same way,
    /// but a well-formed take only ever has one owner set (ADR 0058).
    var ownerKind: OwnerKind {
        if loop != nil { return .loop }
        if exercise != nil { return .exercise }
        if song != nil { return .song }
        return .none
    }

    /// Duration as `m:ss` for the Takes list (ADR 0069 slice 3). Plain string formatting — no UI
    /// dependency — so it stays with the model.
    var durationLabel: String {
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// What a row calls this take: its name, or the generic word every take used to be stuck with.
    /// Every existing row keeps rendering unchanged and no call site has to unwrap.
    var displayTitle: String { title ?? "Take" }

    /// Name (or rename) this take, following `SavedChord.rename(to:)`: trim, and refuse an empty
    /// result rather than storing whitespace that would render as a blank row.
    func rename(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        title = trimmed
    }

    /// Whether this take carries a note — what a list row's marker glyph binds to.
    var hasNote: Bool { !(note ?? "").isEmpty }

    /// Write (or clear) this take's note. Unlike `rename(to:)`, an empty result **is** meaningful
    /// here and clears the note rather than being refused: naming a take is how you tell it apart, so
    /// a blank name is a mistake, but a note you no longer want is a note you should be able to
    /// delete. Whitespace still stores as `nil`, never as a note that renders as an empty block.
    func setNote(_ newNote: String) {
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        note = trimmed.isEmpty ? nil : trimmed
    }
}
