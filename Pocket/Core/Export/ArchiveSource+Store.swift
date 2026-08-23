import Foundation
import SwiftData

/// Reading the whole store into an `ArchiveSource` (ADR 0181).
///
/// Its own file so `ArchiveBuilder` stays free of SwiftData. That is not tidiness: the builder holds
/// every rule about what may cross into an archive, and those rules are unit-tested over plain
/// uninserted models because inserting into a container traps in the XCTest host. The moment the
/// builder imports SwiftData, the temptation is to hand it a `ModelContext` and the tests stop being
/// possible.
extension ArchiveSource {

    /// Everything, in no particular order — `ArchiveBuilder.snapshot` sorts.
    ///
    /// Ten unsorted fetches rather than ten `@Query`s on the screen: an export is a one-shot read, and
    /// live queries would keep the whole library resident for as long as the Settings screen is open.
    ///
    /// **Top-level types only.** Loops, markers, blocks, moments and links all arrive through their
    /// owners, because that is how they are stored and how the archive nests them. `TakeNote` and
    /// `RoutineItem` are not fetched here for the same reason.
    @MainActor
    static func everything(in context: ModelContext) throws -> ArchiveSource {
        var source = ArchiveSource()
        source.songs = try context.fetch(FetchDescriptor<Song>())
        source.exercises = try context.fetch(FetchDescriptor<Exercise>())
        source.savedChords = try context.fetch(FetchDescriptor<SavedChord>())
        source.routines = try context.fetch(FetchDescriptor<Routine>())
        source.goals = try context.fetch(FetchDescriptor<Goal>())
        source.longTermGoals = try context.fetch(FetchDescriptor<LongTermGoal>())
        source.runs = try context.fetch(FetchDescriptor<PracticeRun>())
        source.journal = try context.fetch(FetchDescriptor<JournalEntry>())
        source.recordings = try context.fetch(FetchDescriptor<Recording>())
        // At most one, by design (ADR 0113) — but fetch rather than assume, so a store that somehow
        // holds two exports the first instead of trapping.
        source.profile = try context.fetch(FetchDescriptor<Profile>()).first
        return source
    }
}
