import Foundation

/// Where the strip goes when a note is placed on the neck (ADR 0234 D3). With Chords off it **moves on**
/// to the next note, silently, and the marks (bend, vibrato, *Into it*) stay on the note just placed until
/// the next one is, so adding a bend is still one tap. With Chords on it stays, since a shape takes
/// several taps; on the last note there's nowhere to go.
///
/// Pure and SwiftUI-free (AGENTS.md).
enum NamingCursor {

    struct Move: Equatable, Sendable {
        /// The note the strip is on.
        let active: Int
        /// The note the marks go on, when it isn't `active`.
        let marked: Int?
    }

    static func afterPlacing(at index: Int, count: Int, chords: Bool) -> Move {
        guard !chords, index < count - 1 else { return Move(active: index, marked: nil) }
        return Move(active: index + 1, marked: index)
    }
}
