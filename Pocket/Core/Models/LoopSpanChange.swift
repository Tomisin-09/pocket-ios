import Foundation
import SwiftData

/// One recorded edit to a loop's span (ADR 0199) — cascade-owned by its `Loop`.
///
/// **Why this exists.** `Loop.start` / `Loop.end` are overwritten in place, so narrowing a loop —
/// the single most informative thing a player does with one — used to leave no trace at all. A
/// span that reads `1:58 – 2:04` today says nothing about whether it was set there, or arrived
/// there from `1:44 – 2:18` across three sittings. The second reading is the one worth having:
/// isolating a passage, slowing it, and re-entering it is the shape of deliberate practice, and
/// it is generated for free by using the app — no rating, no tagging, no prose.
///
/// **Each row is self-contained.** It carries the span *before* as well as *after*, so a single
/// row answers "widen back to where it was" without walking the chain, and so a loop that existed
/// before this ADR loses nothing: its first recorded change still carries the original bounds.
/// There is deliberately no row written at creation — the first change's `previous` pair *is* the
/// creation record, which keeps the write to one site.
///
/// **No enum attribute.** ADR 0036's migration crash was a custom enum on a `@Model`; whether a
/// change narrowed, widened or slid is derived from the numbers here rather than stored, so this
/// model is primitives and one relationship.
@Model
final class LoopSpanChange {
    /// Stable business id (ADR 0090) — the `persistentModelID` is unstable before insert.
    var uid: UUID

    /// When the edit was saved.
    var changedAt: Date

    /// The span after the edit, as fractions of the song (0...1) — matching `Loop.start`/`end`.
    var start: Double
    var end: Double

    /// The span before the edit, same units. Never `nil`: a row is only written when something
    /// actually moved, so there is always a previous pair to record.
    var previousStart: Double
    var previousEnd: Double

    /// The playback speed (× of original) in force when the edit was made, or `nil` when it could
    /// not be read. Stored because the narrowing and the slowing are one behaviour, not two facts:
    /// "narrowed and dropped to 0.72×" is the sentence worth being able to write, and reconstructing
    /// the speed afterwards from `PracticeRun` is guesswork about which run this edit sat inside.
    var speed: Double?

    /// The song's duration when the edit was made, in seconds — so a span can be read back in
    /// seconds without depending on the audio still being linked (ADR 0152 relinking) or on the
    /// file being the same length. `nil` when the duration was unknown at write time.
    var songDuration: TimeInterval?

    var loop: Loop?

    init(changedAt: Date = .now,
         start: Double, end: Double,
         previousStart: Double, previousEnd: Double,
         speed: Double? = nil,
         songDuration: TimeInterval? = nil) {
        self.uid = UUID()
        self.changedAt = changedAt
        self.start = start
        self.end = end
        self.previousStart = previousStart
        self.previousEnd = previousEnd
        self.speed = speed
        self.songDuration = songDuration
    }

    /// The span's width after the edit, as a fraction of the song.
    var width: Double { end - start }
    /// The span's width before the edit.
    var previousWidth: Double { previousStart < previousEnd ? previousEnd - previousStart : 0 }

    /// Width after the edit, in seconds — `nil` when the duration wasn't recorded.
    var widthSeconds: TimeInterval? { songDuration.map { $0 * width } }
    /// Width before the edit, in seconds — `nil` when the duration wasn't recorded.
    var previousWidthSeconds: TimeInterval? { songDuration.map { $0 * previousWidth } }
}
