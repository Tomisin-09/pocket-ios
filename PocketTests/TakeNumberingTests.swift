import Foundation
import SwiftData
import XCTest
@testable import Pocket

/// A take is numbered where it was recorded (ADR 0307): the pure rule (D7), the name it's shown by
/// (D3, D4), the export stem (D6), the number given at capture (D1), the backfill (D8) and the
/// archive key.
final class TakeNumberingTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)
    private let firstOfOctober = Date(timeIntervalSince1970: 1_790_856_000)
    private let british = Locale(identifier: "en_GB")
    private let utc = TimeZone(secondsFromGMT: 0) ?? .current

    // MARK: - The rule (D1, D7)

    func testTheFirstTakeIsOne() {
        XCTAssertEqual(TakeNumbering.next(after: []), 1)
    }

    func testTheNextIsOneAboveTheHighestSoAGapStaysAGap() {
        XCTAssertEqual(TakeNumbering.next(after: [1, 2, 3]), 4)
        // Take 2 deleted: the next is still 4, and nothing fills the gap.
        XCTAssertEqual(TakeNumbering.next(after: [3, 1]), 4)
    }

    /// D1 accepts this rather than a stored counter: deleting the newest lets its number come back.
    func testDeletingTheNewestLetsItsNumberComeBack() {
        XCTAssertEqual(TakeNumbering.next(after: [1, 2, 3, 4]), 5, "Take 5 was deleted; the next is Take 5 again")
    }

    func testAGroupIsNumberedInRecordedOrderAboveItsHighest() {
        let entries: [TakeNumbering.Entry<String>] = [
            .init(group: "chorus", recordedAt: start.addingTimeInterval(30), number: nil, tiebreak: "c"),
            .init(group: "chorus", recordedAt: start.addingTimeInterval(10), number: nil, tiebreak: "a"),
            .init(group: "chorus", recordedAt: start.addingTimeInterval(50), number: 2, tiebreak: "e"),
            .init(group: "verse", recordedAt: start.addingTimeInterval(20), number: nil, tiebreak: "b")
        ]
        let assigned = TakeNumbering.backfill(entries)
        XCTAssertEqual(assigned, [1: 3, 0: 4, 3: 1],
                       "the chorus counts on from its highest, 2, oldest first; the verse starts at 1")
        XCTAssertNil(assigned[2], "a take that has a number keeps it")
    }

    func testTwoTakesInTheSameInstantAlwaysComeOutInTheSameOrder() {
        let entries: [TakeNumbering.Entry<Int>] = [
            .init(group: 0, recordedAt: start, number: nil, tiebreak: "b"),
            .init(group: 0, recordedAt: start, number: nil, tiebreak: "a")
        ]
        XCTAssertEqual(TakeNumbering.backfill(entries), [1: 1, 0: 2])
    }

    func testAPassOverNumberedTakesGivesNothing() {
        let entries: [TakeNumbering.Entry<Int>] = [
            .init(group: 0, recordedAt: start, number: 1, tiebreak: "a"),
            .init(group: 1, recordedAt: start, number: 4, tiebreak: "b")
        ]
        XCTAssertTrue(TakeNumbering.backfill(entries).isEmpty)
    }

    // MARK: - The name (D3, D4)

    func testANumberedTakeIsCalledByItsNumberAndANamedOneByItsName() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.takeNumber = 3
        XCTAssertEqual(take.displayTitle, "Take 3")
        take.rename(to: "Bridge run")
        XCTAssertEqual(take.displayTitle, "Bridge run", "the player's name wins")
    }

    func testClearingTheNameBringsTheNumberBack() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.takeNumber = 3
        take.rename(to: "Bridge run")
        take.rename(to: "   \n ")
        XCTAssertNil(take.title)
        XCTAssertEqual(take.displayTitle, "Take 3")
    }

    func testSearchFindsTheNumberThatIsShown() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.takeNumber = 3
        XCTAssertTrue(TextMatch.matchesAllTokens(JournalTimeline.searchHaystack(for: .take(take)),
                                                 query: "take 3"))
    }

    // MARK: - The export (D6)

    func testANumberedTakeExportsAsItsCaptionAndItsNumber() {
        func stem(_ owner: String?) -> String {
            TakeExportName.stem(title: nil, ownerLabel: owner, takeNumber: 3, createdAt: firstOfOctober,
                                locale: british, timeZone: utc)
        }
        XCTAssertEqual(stem("Slow Bend · Chorus"), "Slow Bend · Chorus · Take 3 · 1 Oct 2026")
        XCTAssertEqual(stem("Spider walk · exercise"), "Spider walk · exercise · Take 3 · 1 Oct 2026")
        XCTAssertEqual(stem("Metronome"), "Metronome · Take 3 · 1 Oct 2026")
        XCTAssertEqual(stem(nil), "Take 3 · 1 Oct 2026", "a Journal ＋ take has no caption")
    }

    func testANamedTakeExportsAsItsNameEvenWithANumber() {
        XCTAssertEqual(TakeExportName.stem(title: "Clean run", ownerLabel: "Slow Bend · Chorus", takeNumber: 3,
                                           createdAt: firstOfOctober, locale: british, timeZone: utc),
                       "Clean run · 1 Oct 2026")
    }

    // MARK: - At capture (D1)

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self, Routine.self,
            RoutineItem.self, Goal.self, Recording.self, TakeNote.self, PracticeRun.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func capture(_ owner: RecordingOwner, in context: ModelContext, at offset: TimeInterval = 0) -> Recording {
        let take = Recording(fileName: "\(UUID().uuidString).m4a", duration: 10,
                             createdAt: start.addingTimeInterval(offset))
        owner.attach(to: take, in: context)
        context.insert(take)
        return take
    }

    func testALoopCountsEveryModeTogetherAndAnExerciseCountsItsOwn() throws {
        let context = try makeContext()
        let loop = Loop(name: "Chorus", start: 0.1, end: 0.4, speed: 1, repeats: 1)
        let exercise = Exercise(name: "Spider walk")
        context.insert(loop)
        context.insert(exercise)

        let ramp = capture(.loop(loop, .trainer), in: context)
        let ear = capture(.loop(loop, .ear), in: context)
        let drill = capture(.exercise(exercise), in: context)

        XCTAssertEqual(ramp.takeNumber, 1)
        XCTAssertEqual(ear.takeNumber, 2, "a loop's takes are one count whatever mode recorded them")
        XCTAssertEqual(drill.takeNumber, 1, "the exercise counts its own")
    }

    func testTheMetronomeAndTheJournalPlusEachKeepOneCount() throws {
        let context = try makeContext()
        let sitting = MetronomeJournalContext(bpm: 92, timeSignature: .standard, subdivision: .none,
                                              withdrawal: .off)
        let first = capture(.metronome(sitting), in: context)
        let loose = capture(.standalone, in: context)
        try context.save()
        let second = capture(.metronome(sitting), in: context)

        XCTAssertEqual(first.takeNumber, 1)
        XCTAssertEqual(second.takeNumber, 2)
        XCTAssertEqual(loose.takeNumber, 1, "the Journal ＋ counts apart from the metronome")
    }

    // MARK: - The backfill (D8)

    func testTheBackfillNumbersOldTakesInRecordedOrderAndThenFindsNothing() throws {
        let context = try makeContext()
        let loop = Loop(name: "Chorus", start: 0.1, end: 0.4, speed: 1, repeats: 1)
        context.insert(loop)
        let later = Recording(fileName: "b.m4a", duration: 10, createdAt: start.addingTimeInterval(60))
        let earlier = Recording(fileName: "a.m4a", duration: 10, createdAt: start)
        let orphan = Recording(fileName: "c.m4a", duration: 10, createdAt: start)
        for take in [later, earlier, orphan] { context.insert(take) }
        later.loop = loop
        earlier.loop = loop
        earlier.rename(to: "First go")
        orphan.ownerLabelAtTake = "Old song · Verse"
        try context.save()

        TakeNumberBackfill.run(into: context)

        XCTAssertEqual(earlier.takeNumber, 1, "a named take is numbered too, so the count includes it")
        XCTAssertEqual(earlier.displayTitle, "First go", "and its name still shows")
        XCTAssertEqual(later.takeNumber, 2)
        XCTAssertEqual(orphan.takeNumber, 1, "a take whose owner went counts with its caption")

        // A take captured after it counts on from there, and a second run writes nothing.
        let next = capture(.loop(loop, .ear), in: context, at: 120)
        XCTAssertEqual(next.takeNumber, 3)
        TakeNumberBackfill.run(into: context)
        XCTAssertEqual([earlier.takeNumber, later.takeNumber, next.takeNumber], [1, 2, 3])
    }

    // MARK: - The archive

    @MainActor
    func testAnArchiveFromBeforeTheNumberDecodesWithoutOne() throws {
        var record = ArchiveBuilder.recordingRecord(Recording(fileName: "x.m4a", duration: 12))
        record.takeNumber = 3
        let data = try JSONEncoder().encode(record)
        XCTAssertEqual(try JSONDecoder().decode(RecordingRecord.self, from: data).takeNumber, 3, "it rides")

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "takeNumber")
        let older = try JSONSerialization.data(withJSONObject: json)
        XCTAssertNil(try JSONDecoder().decode(RecordingRecord.self, from: older).takeNumber,
                     "an older archive has no key, and the take still decodes")
    }
}
