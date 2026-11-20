import Foundation
import SwiftData

/// Numbers every take that has no number yet (ADR 0307 D8): the takes recorded before 0307, and any
/// restored from an archive written before it.
///
/// Group by group, as a take is counted at capture (D1): a loop's takes in every mode, an exercise's,
/// a song's, the metronome's, the Journal ＋'s. In the order they were recorded, starting above the
/// highest number the group already has. Named takes are numbered too, so the count includes every
/// take; their names still show.
///
/// A take whose owner was deleted (ADR 0151) has no relationship left to count by, so it counts with
/// the other takes that kept the same caption, which is what it still says it was recorded on.
///
/// **Runs every launch**, for `PieceDateBackfill`'s reason, and after a restore: an archive from an
/// older build arrives without numbers. One fetch of every take, filtered in memory; after the first
/// run it finds nothing to number and writes nothing.
enum TakeNumberBackfill {

    /// The count a take belongs to. Plain values, never the models, so grouping can't fault a
    /// relationship twice.
    enum Group: Hashable {
        case loop(UUID), exercise(UUID), song(String), metronome, standalone
        /// An owner that was deleted, by the caption the take kept.
        case orphan(String?)
    }

    static func group(of take: Recording) -> Group {
        if let loop = take.loop { return .loop(loop.uid) }
        if let exercise = take.exercise { return .exercise(exercise.uid) }
        if let song = take.song { return .song(song.sourceID) }
        if take.isMetronome == true { return .metronome }
        if take.isStandalone == true { return .standalone }
        return .orphan(take.ownerLabelAtTake)
    }

    /// Give a number to every take without one. A failed fetch or save writes nothing, and the next
    /// launch tries again.
    static func run(into context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Recording>()),
              all.contains(where: { $0.takeNumber == nil }) else { return }
        let entries = all.map {
            TakeNumbering.Entry(group: group(of: $0), recordedAt: $0.createdAt,
                                number: $0.takeNumber, tiebreak: $0.uid.uuidString)
        }
        let assigned = TakeNumbering.backfill(entries)
        guard !assigned.isEmpty else { return }
        for (index, number) in assigned { all[index].takeNumber = number }
        try? context.save()
    }
}
