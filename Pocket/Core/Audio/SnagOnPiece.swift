import Foundation

/// Where a **snag** falls on a piece (ADR 0234 D7). A snag is a point on the song in seconds (ADR 0200 D6)
/// and so is every tap of a piece (ADR 0225 D3), so a snag is already on a note: the one nearest it. One
/// made on a note while naming sits exactly on its tap. One made while playing is a reaction, so it lands a
/// moment after the note that caught, and nearest still finds it, the earlier of two when it's halfway.
///
/// Only snags inside the loop's region are the piece's, the positional rule the practice screen already
/// draws by (ADR 0203 D1): what the loop covers, not which loop was armed.
///
/// Pure and SwiftUI-free (AGENTS.md).
enum SnagOnPiece {

    /// How far from a tap a snag can be and still be on it. Past this it reads by its time instead.
    static let reach: TimeInterval = 1.0

    /// The tap nearest `seconds`, within `reach`, or `nil`.
    static func note(at seconds: TimeInterval, taps: [TimeInterval]) -> Int? {
        guard let nearest = taps.indices.min(by: { abs(taps[$0] - seconds) < abs(taps[$1] - seconds) }),
              abs(taps[nearest] - seconds) <= reach else { return nil }
        return nearest
    }
}
