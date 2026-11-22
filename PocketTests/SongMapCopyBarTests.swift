import XCTest
@testable import Pocket

/// A copy keeps each tap's place in the bar (ADR 0310 D3), a copy shifts by a beat (D4), and a copy is the
/// map's while it's as the map made it (D5). Pure arithmetic over plain values, the kind that breaks silently.
final class SongMapCopyBarTests: SongMapSlice3bCase {

    // MARK: - Places in the bars

    func testATimeIsSoManyBarsInAndSoFarIntoTheBar() {
        let grid = grid()
        XCTAssertEqual(SongMapBars.place(of: 8.5, in: grid), 4.25, "a quarter of the way into the fifth bar")
        XCTAssertEqual(SongMapBars.seconds(at: 4.25, in: grid), 8.5)
        XCTAssertEqual(SongMapBars.place(of: -1, in: grid), -0.5, "before the first downbeat, at the bar's length")
        XCTAssertEqual(SongMapBars.place(of: 66, in: grid), 33, "past the last downbeat, the same")
        XCTAssertEqual(SongMapBars.seconds(at: 33, in: grid), 66)
    }

    func testABeatMapsBarsAreMeasuredAsTheyArePlayed() {
        let grid = SongMapInput.Grid(downbeats: [0, 2, 4, 6.5, 9], barSeconds: 2)
        XCTAssertEqual(SongMapBars.place(of: 5.25, in: grid), 2.5, "halfway through a bar 2.5 s long")
        XCTAssertEqual(SongMapBars.seconds(at: 2.5, in: grid), 5.25)
    }

    func testAHairBeforeADownbeatCountsAsItsBar() {
        XCTAssertEqual(SongMapBars.bar(of: 7.995, in: grid()), 4, "a loop's edge read back a hair early")
        XCTAssertEqual(SongMapBars.bar(of: 7.9, in: grid()), 3)
    }

    // MARK: - D3, a copy keeps its place in the bar

    /// Tomisin's *Sunday Morning guitar cover*, as the phone's store had it on 2026-11-21: the *Chords* loop
    /// starts on beat 2 of bar 1, and *Solo start* on beat 4 of bar 64. Copied by distance from the marker,
    /// every chord landed half a bar out. Copied by its place in the bar, the Dm7 is on beat 2 again, in bar 65.
    func testTheSolosChordsLandOnTheirBeatsThoughTheSectionStartsOnBeatFour() throws {
        let grid = SongMapInput.Grid(downbeats: Array(stride(from: 0.46, to: 274.18, by: 240 / 88.2490352868307)),
                                     barSeconds: 240 / 88.2490352868307)
        let seconds = [1.2675283446712018, 2.5414055325357583, 3.829137958839613, 5.136031382875894,
                       5.62689306088043, 6.621405532535759, 7.92827628083508, 9.343854875283447,
                       10.560793650793651, 11.032653061224489]
        let source = SongMapCopy.Source(piece: PieceTranscription(taps: seconds.map { chord($0, 2) }),
                                        start: 1.268, end: 12.105)
        let taps = SongMapCopy.taps(of: source, across: (173.805, 274.181), grid: grid)

        let first = try XCTUnwrap(taps.first)
        XCTAssertEqual(SongMapBars.bar(of: first.seconds, in: grid), 64, "the first pass is in bar 65")
        func beat(_ time: TimeInterval) -> Double {
            SongMapBars.place(of: time, in: grid).truncatingRemainder(dividingBy: 1) * 4 + 1
        }
        XCTAssertEqual(beat(first.seconds), beat(seconds[0]), accuracy: 1e-9, "the Dm7 on the beat it was on")
        for (index, tap) in taps.enumerated() {
            XCTAssertEqual(beat(tap.seconds), beat(seconds[index % seconds.count]), accuracy: 1e-9,
                           "tap \(index) is off its beat")
        }
        XCTAssertTrue(taps.allSatisfy { $0.seconds >= 173.805 && $0.seconds < 274.181 })
        XCTAssertEqual(taps.count, 91, "nine passes of four bars, and a tenth's first chord before the song ends")
    }

    func testAPlaceStartingPastTheFirstTapsPlaceStartsAtTheNextBar() {
        // The changes are each a quarter of a second, an eighth of a bar, late. A place starting a quarter
        // of a bar in can't hold the first, so the first pass is a bar on.
        let taps = SongMapCopy.taps(of: verseChanges(), across: (24.5, 40), grid: grid())
        XCTAssertEqual(taps.map(\.seconds), [26.25, 28.25, 30.25, 32.25, 34.25, 36.25, 38.25])
        XCTAssertEqual(taps.first?.label, changes().taps.first?.label, "starting from the first chord")
    }

    func testAMarkerAHairAfterTheOneStillTakesItsBar() {
        // 24.3 is 0.05 s after where the first chord goes, under a sixteenth of a bar, so it fits: at the start.
        let taps = SongMapCopy.taps(of: verseChanges(), across: (24.3, 40), grid: grid())
        XCTAssertEqual(taps.first?.seconds, 24.3)
        XCTAssertEqual(taps.dropFirst().first?.seconds, 26.25)
    }

    func testABeatMapsBarsKeepEachTapAtItsPlace() {
        // Four bars of 2 s, then four of 2.5 s: a chord a quarter into each bar stays a quarter in.
        let grid = SongMapInput.Grid(downbeats: [0, 2, 4, 6, 8, 10.5, 13, 15.5, 18], barSeconds: 2)
        let piece = PieceTranscription(taps: [chord(0.5, 0), chord(2.5, 5), chord(4.5, 7), chord(6.5, 0)])
        let source = SongMapCopy.Source(piece: piece, start: 0, end: 8)
        let taps = SongMapCopy.taps(of: source, across: (8, 18), grid: grid)
        XCTAssertEqual(taps.map(\.seconds), [8.625, 11.125, 13.625, 16.125])
    }

    // MARK: - D4, a shift by a beat

    func testAShiftMovesEveryTapABeatThroughTheBarLine() {
        let piece = PieceTranscription(taps: [chord(24.25, 0), chord(25.75, 5)])
        let later = SongMapCopy.shifted(piece, by: 1, within: (24, 32), grid: grid())
        XCTAssertEqual(later.taps.map(\.seconds), [24.75, 26.25], "the last beat of a bar goes to the next bar's 1")
        XCTAssertEqual(later.taps.map(\.label), piece.taps.map(\.label))
        let back = SongMapCopy.shifted(later, by: -1, within: (24, 32), grid: grid())
        XCTAssertEqual(back.taps.map(\.seconds), [24.25, 25.75])
    }

    func testATapShiftedOutOfTheLoopIsLeftOff() {
        let piece = PieceTranscription(taps: [chord(24.25, 0), chord(31.75, 5)])
        XCTAssertEqual(SongMapCopy.shifted(piece, by: -1, within: (24, 32), grid: grid()).taps.map(\.seconds),
                       [31.25])
        XCTAssertEqual(SongMapCopy.shifted(piece, by: 1, within: (24, 32), grid: grid()).taps.map(\.seconds),
                       [24.75])
    }

    func testABeatIsTheBarOverItsBeats() {
        var waltz = grid()
        waltz.beatsPerBar = 3
        let piece = PieceTranscription(taps: [chord(24, 0)])
        let moved = SongMapCopy.shifted(piece, by: 1, within: (24, 32), grid: waltz).taps.map(\.seconds)
        XCTAssertEqual(moved.first ?? 0, 24 + 2.0 / 3, accuracy: 1e-9)
    }

    // MARK: - D5, the map's copy

    func testACopyIsStampedWhenItsMade() throws {
        let target = SongMapCopy.Target(start: 24, end: 32, title: "", place: nil, name: "Copy", alongside: [])
        let now = Date(timeIntervalSince1970: 1_000)
        let copy = try XCTUnwrap(SongMapCopy.copies(of: verseChanges(), into: [target], grid: grid(),
                                                    existingNames: [], now: now).first)
        XCTAssertEqual(copy.piece.copiedAt, now)
        XCTAssertEqual(copy.piece.changedAt, now)
    }

    func testACopyIsTheMapsOnlyWhileItsAsTheMapMadeIt() {
        let made = Date(timeIntervalSince1970: 1_000)
        let untouched = SongMapCopy.Standing(copiedAt: made, changedAt: made, keepsVersions: false, hasHistory: false)
        XCTAssertTrue(SongMapCopy.isTheMaps(untouched))
        var counted = untouched
        counted.copiedAt = nil
        XCTAssertFalse(SongMapCopy.isTheMaps(counted), "a piece the player counted, or a copy made before 0310")
        var named = untouched
        named.changedAt = made.addingTimeInterval(1)
        XCTAssertFalse(SongMapCopy.isTheMaps(named), "named or saved since")
        var versioned = untouched
        versioned.keepsVersions = true
        XCTAssertFalse(SongMapCopy.isTheMaps(versioned), "a pass saved over it")
        var practised = untouched
        practised.hasHistory = true
        XCTAssertFalse(SongMapCopy.isTheMaps(practised), "something hangs off the loop")
    }

    func testTheStampSurvivesStorageAndAPieceWithoutOneStillReads() throws {
        var piece = changes()
        let made = Date(timeIntervalSinceReferenceDate: 816_871_416.422_11)
        piece.changedAt = made
        piece.copiedAt = made
        let read = try XCTUnwrap(PieceTranscription.decoded(from: piece.encoded()))
        XCTAssertEqual(read, piece)
        XCTAssertEqual(read.copiedAt, read.changedAt, "still the map's once stored")
        let older = Data(#"{"version":1,"taps":[{"seconds":1.5}],"changedAt":816871416.42211}"#.utf8)
        let old = try XCTUnwrap(PieceTranscription.decoded(from: older), "a piece saved before the stamp")
        XCTAssertNil(old.copiedAt)
    }
}
