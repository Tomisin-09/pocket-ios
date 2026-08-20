import Foundation
import SwiftData

/// A **moment** — one note pinned to a point in a practice take (ADR 0175).
///
/// The thing ADR 0174 declined and parked: a take's own `note` says what the take was like as a
/// whole, and a moment says what happened *at 1:20*. Both exist because they are different thoughts
/// — "rushing throughout" is not "the turnaround here is where it falls apart" — and the second one
/// is worthless without the timestamp that puts you back on it.
///
/// **A dedicated entity, not a `JournalEntry`.** 0174 settled that a take's writing belongs to the
/// audio the way its title does, and nothing about pinning it to a time changes that: a moment is
/// unreadable away from the strip it points into, so it does not go on the Journal feed and Journal
/// search does not match its words. What is new here is only that there can be many of them.
///
/// **Cascade-owned by the take** (`Recording.moments`) — the opposite of ADR 0151's rule for the
/// take itself. A take outlives its loop because the audio is the irreplaceable artifact; a moment
/// is a pointer *into* that audio and means nothing once it is gone, so it goes when the take goes.
@Model
final class TakeNote {

    /// Stable business id — list diffing and sheet presentation, like `Marker`/`Loop`/`Recording`
    /// (the SwiftData `persistentModelID` is unstable before insert, ADR 0090).
    var uid: UUID

    /// Where in the take this note points, in seconds from the take's start. Rewritten by a trim,
    /// which moves the take's zero — see `TakeMoments.rebase`.
    var time: TimeInterval

    /// What was written. Never empty: a moment with no words is a mark with nothing to say, and the
    /// way to remove one is to delete the row. This is where it parts from `Recording.note`, where
    /// clearing the text *is* the delete gesture because there is only ever the one.
    var text: String

    /// When the note was written — not when it points at. Ordering is by `time`, so this exists for
    /// the same reason `Recording.createdAt` does: it is the only thing that can tell two otherwise
    /// identical rows apart.
    var createdAt: Date

    /// The take this moment belongs to. Inverse of `Recording.moments`, whose `.cascade` is what
    /// makes the delete rule fire at all — a bare unidirectional relationship would leave this
    /// pointing at a deleted model instead of clearing.
    var recording: Recording?

    init(time: TimeInterval, text: String, uid: UUID = UUID(), createdAt: Date = Date()) {
        self.uid = uid
        self.time = max(0, time)
        self.text = text
        self.createdAt = createdAt
    }

    /// Where this note points, as `m:ss` — what the row's timecode reads. Plain formatting with no
    /// UI dependency, mirroring `Recording.durationLabel`, so it stays with the model rather than
    /// borrowing the waveform layer's `timecode(_:)`.
    var timeLabel: String {
        let total = Int(time.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Rewrite this moment's words. Trims, and **refuses** an empty result rather than storing a
    /// blank row — the inverse of `Recording.setNote`, and for the reason given on `text`.
    @discardableResult
    func setText(_ newText: String) -> Bool {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        text = trimmed
        return true
    }
}
