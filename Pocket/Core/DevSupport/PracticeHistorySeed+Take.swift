#if DEBUG
import Foundation
import SwiftData

/// The seeded **practice take** (ADR 0165 Phase 5, extended by ADR 0174).
///
/// Split out of `PracticeHistorySeed` when writing real audio pushed that file past the 400-line
/// cap — and it earns its own file anyway: every other part of the seed inserts model rows, and this
/// is the only one that puts **bytes on disk**.
extension PracticeHistorySeed {

    // MARK: - The take

    /// One recorded take, owned by a loop so the row renders with its owner caption underneath —
    /// which is the whole subject of `journal/take-row`.
    ///
    /// **Real audio is written**, unlike the rest of this seed. `JournalTakeRow` renders entirely from
    /// the model and needs no bytes behind it, which is why this used to write none — but a take now
    /// opens its own screen (ADR 0174), and that screen reads the envelope off the disk and plays
    /// from it. A fileless take renders there as a flat track over a zero-length timeline: a state
    /// worth *handling*, and the wrong one to photograph.
    ///
    /// The tone is the same generated arpeggio the demo song uses — asset-free and unlicensed — and
    /// it is written through `TakeRecorder.settings`, so a seeded take is the same AAC a recorded one
    /// is and the trim path exercises the format it will meet in the wild. `duration` is taken from
    /// the file rather than asserted, so the row and the screen can't disagree about its length.
    @MainActor
    // Not `private`: `private` is file-scoped, and the caller is `seedIfNeeded` next door.
    static func seedTake(loops: [Loop], into context: ModelContext) {
        guard let day = calendarDay(daysAgo: 1),
              let createdAt = Calendar.current.date(byAdding: .hour, value: 19, to: day)
        else { return }

        let uid = UUID()
        let fileName = RecordingStore.fileName(for: uid)
        let seconds: TimeInterval = 47
        guard let url = try? RecordingStore.url(for: fileName),
              (try? SampleToneGenerator.writeSample(duration: seconds, to: url,
                                                    settings: TakeRecorder.settings)) != nil else {
            return
        }

        let take = Recording(fileName: fileName,
                             duration: seconds,
                             uid: uid,
                             createdAt: createdAt,
                             loop: loops.first)
        // A note on the seeded take, so the detail screen's note block and the row's marker glyph
        // both have something to show (ADR 0174).
        take.setNote("Second half is steadier — the first eight bars are still rushing.")
        context.insert(take)
    }
}
#endif
