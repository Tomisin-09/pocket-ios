import Foundation

/// A place from the model behind it (ADR 0264 D5). Apart from `ReferenceDestination` itself, which is
/// values only, because the share extension compiles that file and has no store (D9, D10): it builds
/// the same values from the owner snapshot instead.
extension ReferenceDestination {
    init(exercise: Exercise) {
        self.init(id: Self.key(.exercise, exercise.uid.uuidString), kind: .exercise,
                  name: Self.displayName(exercise.name), lastPracticed: exercise.lastPracticed)
    }

    init(routine: Routine) {
        self.init(id: Self.key(.routine, routine.uid.uuidString), kind: .routine,
                  name: Self.displayName(routine.name), lastPracticed: routine.lastPracticed)
    }

    init(song: Song) {
        self.init(id: Self.key(.song, song.sourceID), kind: .song, name: Self.displayName(song.title),
                  parent: song.artist, lastPracticed: song.lastPracticed)
    }

    init(loop: Loop) {
        self.init(id: Self.key(.loop, loop.uid.uuidString), kind: .loop, name: Self.displayName(loop.name),
                  parent: loop.song.map { Self.displayName($0.title) }, lastPracticed: loop.song?.lastPracticed)
    }

    /// The key a row's owner goes by, to mark the places a source is already on.
    static func key(of owner: any ReferenceLinkOwner) -> String? {
        switch owner {
        case let exercise as Exercise: key(.exercise, exercise.uid.uuidString)
        case let routine as Routine: key(.routine, routine.uid.uuidString)
        case let song as Song: key(.song, song.sourceID)
        case let loop as Loop: key(.loop, loop.uid.uuidString)
        default: nil
        }
    }

    /// An owner with no name reads as *Untitled*, as `ReferenceLink.place` reads it.
    private static func displayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}
