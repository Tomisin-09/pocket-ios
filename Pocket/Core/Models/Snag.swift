import Foundation
import SwiftData

/// A place the player fluffed it (ADR 0200) — one tap, no sheet, no typing, eyes off the screen.
///
/// **A snag is a point on the song**, cascade-owned by its `Song` exactly like `Marker`, because
/// that is what it is: 2:01 is 2:01 whether or not the loop that was armed at the time still
/// exists. What separates it from a marker is cost and scope — a marker is a named landmark you
/// stop to write, a snag is anonymous and costs one tap, which is the whole point: it has to be
/// affordable *while playing*, or it will not be made.
///
/// **The loop is a loose id copy, not a relationship** — the `PracticeRun.unitUID` shape (ADR
/// 0117), and for the same reason: deleting a loop must never delete the record of what happened
/// while you were playing it. It is also never filtered in a `#Predicate` (the optional-relationship
/// freeze), so a plain `UUID?` is honest about how it is actually read.
///
/// The player marks their own stumble; nothing here is a score. ADR 0070 forbids **the app**
/// grading, and this is self-report — the same standing the journal already has. What it must not
/// become is a count rendered as a trend, which is a grade wearing a chart.
@Model
final class Snag {
    /// Stable business id (ADR 0090).
    var uid: UUID

    /// When the tap happened. Named `markedAt` rather than `at` because SwiftLint's identifier
    /// rule floors names at three characters, and the longer name reads better anyway.
    var markedAt: Date

    /// Where in the song, in seconds — matching `Marker.seconds` rather than `Loop`'s fractions,
    /// because like a marker this is a point on a timeline rather than a region of one.
    var seconds: TimeInterval

    /// The playback speed in force when it was marked, or `nil` when it could not be read.
    /// A snag at 0.6× and a snag at full tempo are not the same admission.
    var speed: Double?

    /// The loop that was armed, by `uid` — a loose copy, never a relationship. `nil` when the
    /// snag was marked with no loop armed.
    var loopUID: UUID?

    var song: Song?

    init(markedAt: Date = .now, seconds: TimeInterval, speed: Double? = nil, loopUID: UUID? = nil) {
        self.uid = UUID()
        self.markedAt = markedAt
        self.seconds = seconds
        self.speed = speed
        self.loopUID = loopUID
    }
}
