import XCTest
@testable import Pocket

/// **Watch the section** (ADR 0289): several loops' pieces merged into one run in song time, the later loop
/// showing where two overlap, gaps lighting nothing, one tuning, and joins kept only where they were named.
final class SectionWatchTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    private func note(_ fret: Int, into: Join? = nil) -> PieceLabel {
        .fretted([FrettedNote(string: 2, fret: fret)], into: into)
    }

    private func source(_ name: String, _ start: TimeInterval, _ end: TimeInterval, reach: TimeInterval? = nil,
                        _ taps: [(TimeInterval, PieceLabel?)], openMidi: [Int]? = nil,
                        chords: Bool = false) -> SectionWatch.Source {
        let piece = PieceTranscription(taps: taps.map { .init(seconds: $0.0, label: $0.1) },
                                       openMidi: openMidi ?? guitar)
        return SectionWatch.Source(id: UUID(), name: name, start: start, end: end, reach: reach ?? end,
                                   piece: piece, isChords: chords)
    }

    private func seconds(_ run: SectionWatch.Run) -> [TimeInterval] { run.taps.map(\.seconds) }

    // MARK: - Merged in song time

    func testLoopsAreMergedInSongTime() {
        let verse = source("Verse riff", 0, 10, [(1, note(5)), (3, note(7))])
        let fill = source("Fill", 12, 20, [(13, note(9)), (15, note(10))])
        let run = SectionWatch.merge([fill, verse], from: 0, to: 20)
        XCTAssertEqual(seconds(run), [1, 3, 13, 15])
        XCTAssertEqual(run.sources.map(\.name), ["Verse riff", "Fill"], "in the order they start")
        XCTAssertEqual([0, 1, 2, 3].map { run.source(startingAt: $0)?.name }, ["Verse riff", nil, "Fill", nil])
    }

    func testALaterLoopShowsOverAnEarlierOneAndTheEarlierComesBack() {
        let riff = source("Riff", 0, 20, [(2, note(5)), (6, note(7)), (12, note(8)), (18, note(10))])
        let lick = source("Lick", 10, 15, [(11, note(12)), (13, note(14))])
        let run = SectionWatch.merge([riff, lick], from: 0, to: 20)
        XCTAssertEqual(seconds(run), [2, 6, 11, 13, 18], "the riff's note under the lick is left out")
        XCTAssertEqual(run.taps.map(\.until), [6, 10, 13, 15, 20],
                       "the riff gives way when the lick starts, and the lick ends with its loop")
    }

    func testAGapLightsNothing() {
        let run = SectionWatch.merge([source("A", 0, 10, [(1, note(5)), (5, note(7))]),
                                      source("B", 20, 30, [(21, note(9))])], from: 0, to: 30)
        XCTAssertEqual([0.5, 1, 5.5, 9.9, 10, 15, 21, 29.9, 30].map { run.heard(at: $0) },
                       [nil, 0, 1, 1, nil, nil, 2, 2, nil])
    }

    // MARK: - What takes part

    func testAPartNamedByEarHidesNothing() {
        let riff = source("Riff", 0, 20, [(2, note(5)), (12, note(7))])
        let chords = source("Chords", 10, 20, [(10, .chord(root: 9, suffix: "m"))], chords: true)
        XCTAssertEqual(seconds(SectionWatch.merge([riff, chords], from: 0, to: 20)), [2, 12])
    }

    func testAPieceInAnotherTuningIsLeftOutAndCounted() {
        let dropD = [64, 59, 55, 50, 45, 38]
        let run = SectionWatch.merge([source("Riff", 0, 10, [(1, note(5))]),
                                      source("Drop D riff", 5, 10, [(6, note(3))], openMidi: dropD)], from: 0, to: 10)
        XCTAssertEqual(seconds(run), [1])
        XCTAssertEqual(run.taps.first?.until, 10, "a loop left out doesn't take over either")
        XCTAssertEqual(run.otherTuning, 1)
        XCTAssertEqual(run.openMidi, guitar)
    }

    func testOnTheSameMomentTheRiffShowsOverTheChords() {
        let shape = PieceLabel.fretted([FrettedNote(string: 1, fret: 5), FrettedNote(string: 2, fret: 5)], into: nil)
        let chords = source("Chords", 0, 10, [(0, shape)], chords: true)
        let riff = source("Riff", 0, 10, [(1, note(7))])
        XCTAssertEqual(seconds(SectionWatch.merge([riff, chords], from: 0, to: 10)), [1])
    }

    // MARK: - Joins and repeats

    func testAJoinIsKeptOnlyAfterTheTapItWasNamedAgainst() {
        let alone = SectionWatch.merge([source("Riff", 0, 20, [(1, note(5)), (12, note(7, into: .legato))])],
                                       from: 0, to: 20)
        XCTAssertEqual(alone.labels[1], note(7, into: .legato))
        let riff = source("Riff", 0, 20, [(1, note(5)), (12, note(7, into: .legato))])
        let lick = source("Lick", 5, 10, [(6, note(9))])
        let run = SectionWatch.merge([riff, lick], from: 0, to: 20)
        XCTAssertEqual(run.labels, [note(5), note(9), note(7)], "after the lick, the hammer-on has no note before")
    }

    func testARepeatPlaysItsTapsOnEveryPass() {
        let riff = source("Riff", 0, 4, reach: 12, [(1, note(5)), (2, note(7, into: .legato))])
        let run = SectionWatch.merge([riff], from: 0, to: 12)
        XCTAssertEqual(seconds(run), [1, 2, 5, 6, 9, 10])
        XCTAssertEqual(run.labels, [note(5), note(7, into: .legato), note(5), note(7, into: .legato), note(5),
                                    note(7, into: .legato)], "each pass keeps its own hammer-on")
        XCTAssertEqual(run.taps.last?.until, 12)
    }

    func testTheSectionClipsTheRun() {
        let run = SectionWatch.merge([source("Riff", 0, 20, [(2, note(5)), (8, note(7)), (14, note(9))])],
                                     from: 5, to: 15)
        XCTAssertEqual(seconds(run), [8, 14])
        XCTAssertEqual(run.taps.last?.until, 15)
        XCTAssertFalse(SectionWatch.hasSomethingToWatch([source("Riff", 0, 20, [(2, note(5))])], from: 5, to: 15),
                       "nothing on the neck in the stretch, so no door")
    }

    // MARK: - One loop

    func testOneLoopIsHeardAsItAlwaysWas() {
        let piece = PieceTranscription(taps: [.init(seconds: 2, label: note(5)), .init(seconds: 4, label: nil)],
                                       openMidi: guitar)
        let run = SectionWatch.run(of: piece, id: UUID(), name: "Riff")
        XCTAssertEqual([1, 2, 3, 4, 100].map { run.heard(at: $0) }, [nil, 0, 0, 1, 1],
                       "the last tap stays heard until the loop goes round")
        XCTAssertEqual(run.labels, [note(5), nil])
    }
}
