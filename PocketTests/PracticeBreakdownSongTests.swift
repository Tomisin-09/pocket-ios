import XCTest
@testable import Pocket

/// *What you played* **by song** (ADR 0295): which row a run lands in, what a song opens onto, and
/// how a song the library no longer holds is named. In its own file because the grouping by kind
/// already fills `PracticeBreakdownTests`.
final class PracticeBreakdownSongTests: XCTestCase {

    private let picking = UUID()
    private let scales = UUID()
    private let soloStart = UUID()
    private let chordsStart = UUID()
    private let slowBend = "slow-bend-source"
    private let sunday = "sunday-source"

    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private var library: PracticeBreakdown.Names {
        PracticeBreakdown.Names(
            exercises: [picking: "Alternate Picking", scales: "Scale Runs"],
            loops: [soloStart: .init(name: "Solo start", songSourceID: slowBend),
                    chordsStart: .init(name: "Chords start", songSourceID: slowBend)],
            songs: [slowBend: "Slow Bend", sunday: "Sunday Morning"])
    }

    private func run(_ kind: PracticeRunKind, unit: UUID? = nil, minutes: Double, after offset: Double = 0,
                     song: String? = nil, label: String? = nil) -> SessionRecord {
        SessionRecord(startedAt: start.addingTimeInterval(offset * 60), durationSeconds: minutes * 60,
                      kind: kind, unitUID: unit, songSourceID: song, unitLabel: label)
    }

    func testBySongASongHoldsItsLoopsEarWorkAndPlayAlongsAsKinds() {
        let rows = PracticeBreakdown.songRows([
            run(.earLoop, unit: soloStart, minutes: 40, song: slowBend),
            run(.earLoop, unit: chordsStart, minutes: 20, after: 50, song: slowBend),
            run(.improvise, unit: chordsStart, minutes: 30, after: 100, song: slowBend),
            run(.song, minutes: 12, after: 200, song: slowBend),
            run(.song, minutes: 15, after: 300, song: sunday)
        ], names: library)

        XCTAssertEqual(rows.map(\.title), ["Slow Bend", "Sunday Morning"])
        guard rows.count == 2 else { return }
        XCTAssertEqual(rows[0].minutes, 102)
        XCTAssertEqual(rows[0].items.map(\.name), ["Ear training", "Improvising", "Play-alongs"],
                       "a song opens onto kinds of work, and two loops' ear work is one row")
        XCTAssertEqual(rows[0].items.map(\.minutes), [60, 30, 12])
    }

    func testBySongEveryRunLandsInExactlyOneRow() {
        let records = [
            run(.exercise, unit: picking, minutes: 7),
            run(.exercise, unit: scales, minutes: 9, after: 10),
            run(.loop, unit: soloStart, minutes: 11, after: 20, song: slowBend),
            run(.earLoop, unit: chordsStart, minutes: 6, after: 32, song: slowBend),
            run(.song, minutes: 13, after: 40),
            run(.metronome, minutes: 5, after: 60),
            run(.other, minutes: 3, after: 70)
        ]
        var names = library
        names.exerciseSongs = [picking: sunday]
        let rows = PracticeBreakdown.songRows(records, names: names)
        XCTAssertEqual(rows.reduce(0) { $0 + $1.seconds }, records.reduce(0) { $0 + $1.durationSeconds },
                       accuracy: 0.001, "the songs add up to what was played")
        for row in rows where !row.items.isEmpty {
            XCTAssertEqual(row.items.reduce(0) { $0 + $1.seconds }, row.seconds, accuracy: 0.001, row.title)
        }
    }

    func testBySongAnExerciseForOneSongCountsUnderIt() {
        var names = library
        names.exerciseSongs = [picking: sunday]
        let rows = PracticeBreakdown.songRows([
            run(.exercise, unit: picking, minutes: 20),
            run(.exercise, unit: scales, minutes: 8, after: 30)
        ], names: names)

        XCTAssertEqual(rows.map(\.title), ["Sunday Morning", "Exercises"])
        guard rows.count == 2 else { return }
        XCTAssertEqual(rows[0].items.map(\.name), ["Exercises"])
        XCTAssertEqual(rows[1].items.map(\.name), ["Scale Runs"],
                       "an exercise for no one song stays under Exercises, by name")
    }

    func testBySongALoopCountsUnderTheSongItBelongsToNow() {
        // Logged before runs recorded a song (ADR 0241 D5), so the row itself names none.
        let rows = PracticeBreakdown.songRows([run(.loop, unit: soloStart, minutes: 10)], names: library)
        XCTAssertEqual(rows.map(\.title), ["Slow Bend"])
    }

    func testBySongADeletedLoopCountsUnderTheSongItWasLoggedWith() {
        let rows = PracticeBreakdown.songRows([
            run(.loop, unit: UUID(), minutes: 10, song: sunday, label: "Bridge")
        ], names: library)
        XCTAssertEqual(rows.map(\.title), ["Sunday Morning"])
    }

    func testBySongRunsWhoseSongWasNeverRecordedShareOneHonestRow() {
        let rows = PracticeBreakdown.songRows([
            run(.song, minutes: 6),
            run(.loop, unit: UUID(), minutes: 4, after: 10, label: "Intro")
        ], names: library)
        XCTAssertEqual(rows.map(\.title), ["Song not recorded"])
        guard let row = rows.first else { return }
        XCTAssertEqual(row.isUnnamed, true)
        XCTAssertEqual(row.minutes, 10)
    }

    func testBySongADeletedSongIsNamedByItsLastPlayAlongOrSaysItCannot() {
        let rows = PracticeBreakdown.songRows([
            run(.song, minutes: 9, song: "gone-1", label: "Old Tune"),
            run(.loop, unit: UUID(), minutes: 4, after: 20, song: "gone-2", label: "Verse")
        ], names: library)
        XCTAssertEqual(rows.map(\.title), ["Old Tune", "A deleted song"],
                       "a loop's label is the loop's name, so it cannot name the song")
        XCTAssertEqual(rows.map(\.detail), ["Deleted", nil])
        XCTAssertEqual(rows.map(\.isUnnamed), [false, true])
    }

    func testBySongASongThatIsAGoalsTargetSaysSo() {
        var names = library
        names.songGoals = [slowBend: "Play a specific song"]
        let rows = PracticeBreakdown.songRows([
            run(.song, minutes: 9, song: slowBend),
            run(.song, minutes: 5, after: 20, song: sunday)
        ], names: names)
        XCTAssertEqual(rows.map(\.detail), ["Goal · Play a specific song", nil])
    }

    func testBySongTheMetronomeHasNothingToOpen() {
        let rows = PracticeBreakdown.songRows([run(.metronome, minutes: 5)], names: library)
        XCTAssertEqual(rows.map(\.title), ["Metronome"])
        XCTAssertEqual(rows.first?.items, [])
    }

    func testBySongEqualSongsKeepAFixedOrder() {
        let rows = PracticeBreakdown.songRows([
            run(.song, minutes: 5, song: sunday),
            run(.song, minutes: 5, after: 10, song: slowBend)
        ], names: library)
        XCTAssertEqual(rows.map(\.title), ["Slow Bend", "Sunday Morning"], "a tie falls back to the title")
    }

    func testRowsByKindAreTheGroupsUnderTheirOwnTitles() {
        let records = [
            run(.exercise, unit: picking, minutes: 25),
            run(.loop, unit: soloStart, minutes: 50, after: 60)
        ]
        let rows = PracticeBreakdown.rows(records, names: library, grouping: .kind)
        let groups = PracticeBreakdown.groups(records, names: library)
        XCTAssertEqual(rows.map(\.title), groups.map(\.kind.groupLabel))
        XCTAssertEqual(rows.map(\.items), groups.map(\.items))
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
    }

    func testTheGroupingOpensByKind() {
        XCTAssertEqual(PracticeBreakdown.Grouping.standard, .kind,
                       "the list reads as it did before the switch existed until the player moves it")
    }
}
