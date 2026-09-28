import Foundation
import SwiftData

/// A named time point on a song's timeline (ADR 0011) — cascade-owned by its `Song`
/// (`Song.markers`). Extracted from `Song.swift` to keep that file under the 400-line limit.
@Model
final class Marker {
    var uid: UUID
    var seconds: TimeInterval
    var label: String
    var song: Song?
    /// Whether this marker starts a **section** of the song map (ADR 0232 D6): the player's own word
    /// that a new part begins here. A marker without it stays a pin. Declaration default, so SwiftData
    /// lightweight migration fills markers saved before it (the CoreData 134110 rule, ADR 0012).
    var startsSection: Bool = false

    init(seconds: TimeInterval, label: String) {
        self.uid = UUID()
        self.seconds = seconds
        self.label = label
    }
}
