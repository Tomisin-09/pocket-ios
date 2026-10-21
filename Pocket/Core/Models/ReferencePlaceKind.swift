import Foundation

/// The four things a reference can be filed on (ADR 0167), as the References library names them.
///
/// `Codable` because the share extension's owner snapshot carries it (ADR 0264 D9), and in a file of its
/// own because the extension compiles it (D10).
enum ReferencePlaceKind: String, CaseIterable, Codable, Sendable {
    case exercise, song, loop, routine

    /// What a *Where it's used* row says under the place's name.
    var noun: String {
        switch self {
        case .exercise: "Exercise"
        case .song: "Song"
        case .loop: "Loop"
        case .routine: "Routine"
        }
    }
}
