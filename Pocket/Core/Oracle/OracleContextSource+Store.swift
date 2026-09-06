import Foundation
import SwiftData

/// Reading the store into an `OracleContextSource` (ADR 0187 D5).
///
/// Its own file so `OracleContextBuilder` stays free of SwiftData — the `ArchiveSource+Store.swift`
/// split, made for a reason that binds harder here: the builder holds every rule about what may
/// cross into a request, and those rules are unit-tested over plain uninserted models because
/// inserting into a container traps in the XCTest host. The moment the builder imports SwiftData,
/// the temptation is to hand it a `ModelContext` and the privacy tests stop being possible.
extension OracleContextSource {

    /// Everything a reading may read, in no particular order — the builder sorts.
    ///
    /// **Loops arrive through their songs**, because that is how they are stored. Note what does
    /// *not* come with them: `OracleContextBuilder.UnitSnapshot` keeps a loop's name and drops its
    /// song entirely, so no title, artist or file name is even in scope by the time the builder
    /// runs (D6 R2).
    ///
    /// `Profile` is not fetched at all. D6 R3 keeps `artistName` on the device — a reading that
    /// addresses the player by name has the name interpolated client-side, and
    /// `PrivacySection.swift:57-58`'s promise about it survives this feature intact. The way to
    /// keep a field from crossing is to not read it.
    @MainActor
    static func forReading(in context: ModelContext) throws -> OracleContextSource {
        var source = OracleContextSource()
        source.exercises = try context.fetch(FetchDescriptor<Exercise>())
        source.loops = try context.fetch(FetchDescriptor<Song>()).flatMap(\.loops)
        source.journal = try context.fetch(FetchDescriptor<JournalEntry>())
        source.takes = try context.fetch(FetchDescriptor<Recording>())
        source.goals = try context.fetch(FetchDescriptor<Goal>())
        source.longTermGoals = try context.fetch(FetchDescriptor<LongTermGoal>())
        source.records = try context.fetch(FetchDescriptor<PracticeRun>()).map(\.record)
        return source
    }
}
