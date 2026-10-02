import XCTest
@testable import Pocket

/// *What you played* (ADR 0241): the grouping by kind and unit, the order, and every naming rule —
/// the live name first, the name a deleted unit was logged under, and an honest placeholder when the
/// log never knew. The view only draws what this returns.
final class PracticeBreakdownTests: XCTestCase {

    private let picking = UUID()
    private let scales = UUID()
    private let soloStart = UUID()
    private let chordsStart = UUID()
    private let slowBend = "slow-bend-source"

    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private var library: PracticeBreakdown.Names {
        PracticeBreakdown.Names(
            exercises: [picking: "Alternate Picking", scales: "Scale Runs"],
            loops: [soloStart: .init(name: "Solo start", songSourceID: slowBend),
                    chordsStart: .init(name: "Chords start", songSourceID: slowBend)],
            songs: [slowBend: "Slow Bend"])
    }

    private func run(_ kind: PracticeRunKind, unit: UUID? = nil, minutes: Double, after offset: Double = 0,
                     song: String? = nil, label: String? = nil) -> SessionRecord {
        SessionRecord(startedAt: start.addingTimeInterval(offset * 60), durationSeconds: minutes * 60,
                      kind: kind, unitUID: unit, songSourceID: song, unitLabel: label)
    }

    // MARK: - Grouping and order

    func testRunsGroupByKindThenByUnitLargestFirstAtBothLevels() {
        let groups = PracticeBreakdown.groups([
            run(.exercise, unit: picking, minutes: 25),
            run(.exercise, unit: scales, minutes: 18, after: 30),
            run(.loop, unit: soloStart, minutes: 50, after: 60),
            run(.loop, unit: chordsStart, minutes: 40, after: 120),
            run(.exercise, unit: picking, minutes: 22, after: 200)
        ], names: library)

        XCTAssertEqual(groups.map(\.kind), [.loop, .exercise], "90 minutes of loops lead 65 of exercises")
        XCTAssertEqual(groups[0].items.map(\.name), ["Solo start", "Chords start"])
        XCTAssertEqual(groups[1].items.map(\.name), ["Alternate Picking", "Scale Runs"])
        XCTAssertEqual(groups[1].items.first?.minutes, 47, "two runs on one exercise are one row")
        XCTAssertEqual(groups[1].minutes, 65)
    }

    func testEqualGroupsAndEqualItemsKeepAFixedOrder() {
        let groups = PracticeBreakdown.groups([
            run(.song, minutes: 10, song: slowBend),
            run(.exercise, unit: scales, minutes: 5),
            run(.exercise, unit: picking, minutes: 5)
        ], names: library)
        XCTAssertEqual(groups.map(\.kind), [.exercise, .song], "a tie falls back to declaration order")
        XCTAssertEqual(groups[0].items.map(\.name), ["Alternate Picking", "Scale Runs"], "and items by name")
    }

    func testARowRoundsOnceFromItsSummedSeconds() {
        // Three 40-second runs are two minutes, not three — the log's one rounding rule.
        let groups = PracticeBreakdown.groups((0..<3).map {
            run(.loop, unit: soloStart, minutes: 40.0 / 60, after: Double($0))
        }, names: library)
        XCTAssertEqual(groups.first?.items.first?.minutes, 2)
    }

    func testEarTrainingAndImprovisingOnOneLoopAreSeparateGroups() {
        let groups = PracticeBreakdown.groups([
            run(.earLoop, unit: soloStart, minutes: 6),
            run(.improvise, unit: soloStart, minutes: 9),
            run(.loop, unit: soloStart, minutes: 3)
        ], names: library)
        XCTAssertEqual(groups.map(\.kind), [.improvise, .earLoop, .loop],
                       "the same material doing a different job is a different kind of practice")
    }

    func testNoRecordsGiveNoGroups() {
        XCTAssertTrue(PracticeBreakdown.groups([], names: library).isEmpty)
    }

    // MARK: - Naming a live unit

    func testALiveUnitIsNamedAsItIsNowNotAsItWasLogged() {
        let groups = PracticeBreakdown.groups([run(.exercise, unit: picking, minutes: 5, label: "Old name")],
                                              names: library)
        let item = groups.first?.items.first
        XCTAssertEqual(item?.name, "Alternate Picking", "a rename shows here the moment it's made")
        XCTAssertNil(item?.detail)
        XCTAssertEqual(item?.isUnnamed, false)
    }

    func testALoopCarriesItsSongUnderneath() {
        let item = PracticeBreakdown.groups([run(.loop, unit: soloStart, minutes: 5)], names: library)
            .first?.items.first
        XCTAssertEqual(item?.name, "Solo start")
        XCTAssertEqual(item?.detail, "Slow Bend")
    }

    func testABlankNameReadsAsUntitled() {
        var names = library
        names.exercises[picking] = ""
        names.loops[soloStart] = .init(name: "", songSourceID: nil)
        let groups = PracticeBreakdown.groups([run(.exercise, unit: picking, minutes: 5),
                                               run(.loop, unit: soloStart, minutes: 4)], names: names)
        XCTAssertEqual(groups.flatMap(\.items).map(\.name), ["Untitled exercise", "Untitled loop"])
    }

    // MARK: - Play-alongs

    func testAPlayAlongIsNamedByItsSong() {
        let groups = PracticeBreakdown.groups([run(.song, minutes: 33, song: slowBend, label: "Slow Bend"),
                                               run(.song, minutes: 4, after: 50, song: slowBend)],
                                              names: library)
        XCTAssertEqual(groups.first?.kind, .song)
        XCTAssertEqual(groups.first?.items.count, 1, "two play-alongs of one song are one row")
        XCTAssertEqual(groups.first?.items.first?.name, "Slow Bend")
        XCTAssertEqual(groups.first?.items.first?.minutes, 37)
    }

    func testPlayAlongsLoggedBeforeTheSongWasRecordedShareOneHonestRow() {
        let groups = PracticeBreakdown.groups([run(.song, minutes: 10), run(.song, minutes: 12, after: 60)],
                                              names: library)
        let item = groups.first?.items.first
        XCTAssertEqual(groups.first?.items.count, 1, "the log cannot tell them apart, so it doesn't try")
        XCTAssertEqual(item?.name, "Song not recorded")
        XCTAssertEqual(item?.isUnnamed, true)
    }

    // MARK: - Deleted units

    func testADeletedUnitIsNamedByWhatItWasLoggedAs() {
        let gone = UUID()
        let item = PracticeBreakdown.groups([run(.exercise, unit: gone, minutes: 8, label: "Spider Walk")],
                                            names: library).first?.items.first
        XCTAssertEqual(item?.name, "Spider Walk")
        XCTAssertEqual(item?.detail, "Deleted", "so it can't be mistaken for something you can open")
        XCTAssertEqual(item?.isUnnamed, false)
    }

    func testTheLatestNameWinsForADeletedUnit() {
        let gone = UUID()
        let item = PracticeBreakdown.groups([
            run(.exercise, unit: gone, minutes: 8, after: 100, label: "Spider Walk v2"),
            run(.exercise, unit: gone, minutes: 8, after: 0, label: "Spider Walk")
        ], names: library).first?.items.first
        XCTAssertEqual(item?.name, "Spider Walk v2", "by start time, whatever order the rows arrive in")
    }

    func testADeletedLoopKeepsItsSongWhenTheSongIsStillHere() {
        let item = PracticeBreakdown.groups([run(.loop, unit: UUID(), minutes: 5, song: slowBend,
                                                 label: "Outro bend")], names: library).first?.items.first
        XCTAssertEqual(item?.name, "Outro bend")
        XCTAssertEqual(item?.detail, "Slow Bend · deleted")
    }

    func testADeletedUnitLoggedBeforeNamesWereKeptIsAPlaceholder() {
        let groups = PracticeBreakdown.groups([run(.exercise, unit: UUID(), minutes: 5),
                                               run(.loop, unit: UUID(), minutes: 4),
                                               run(.song, minutes: 3, song: "a-song-since-deleted")],
                                              names: library)
        let items = groups.flatMap(\.items)
        XCTAssertEqual(items.map(\.name), ["A deleted exercise", "A deleted loop", "A deleted song"])
        XCTAssertTrue(items.allSatisfy(\.isUnnamed))
    }

    func testTwoDeletedUnitsStayTwoRows() {
        let groups = PracticeBreakdown.groups([run(.exercise, unit: UUID(), minutes: 5),
                                               run(.exercise, unit: UUID(), minutes: 4)], names: library)
        XCTAssertEqual(groups.first?.items.count, 2, "keyed by uid, so two placeholders don't merge")
    }

    // MARK: - The metronome (ADR 0242)

    /// Every metronome run is one group, summed, with **nothing inside it** — its runs belong to no
    /// unit, so a row inside would only say "Metronome" again.
    func testMetronomeRunsAreOneGroupWithNothingToOpen() {
        let groups = PracticeBreakdown.groups([
            run(.metronome, minutes: 12),
            run(.metronome, minutes: 8, after: 600)
        ], names: library)

        XCTAssertEqual(groups.map(\.kind), [.metronome])
        XCTAssertEqual(groups.first?.minutes, 20)
        XCTAssertEqual(groups.first?.items, [])
    }

    /// It ranks by minutes with everything else, and having nothing to open doesn't empty the groups
    /// around it.
    func testTheMetronomeRanksByMinutesAmongTheOtherKinds() {
        let groups = PracticeBreakdown.groups([
            run(.exercise, unit: picking, minutes: 10),
            run(.metronome, minutes: 25, after: 30),
            run(.loop, unit: soloStart, minutes: 5, after: 90)
        ], names: library)

        XCTAssertEqual(groups.map(\.kind), [.metronome, .exercise, .loop])
        XCTAssertEqual(groups[1].items.map(\.name), ["Alternate Picking"])
        XCTAssertEqual(groups[2].items.map(\.name), ["Solo start"])
    }

    // MARK: - A row from a newer build

    func testARowOfAnUnknownKindStillCountsAndClaimsNothing() {
        let groups = PracticeBreakdown.groups([run(.other, minutes: 7)], names: library)
        XCTAssertEqual(groups.first?.kind, .other)
        XCTAssertEqual(groups.first?.minutes, 7)
        XCTAssertEqual(groups.first?.items.first?.isUnnamed, true)
    }
}
