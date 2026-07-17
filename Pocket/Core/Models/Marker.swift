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

    init(seconds: TimeInterval, label: String) {
        self.uid = UUID()
        self.seconds = seconds
        self.label = label
    }
}
