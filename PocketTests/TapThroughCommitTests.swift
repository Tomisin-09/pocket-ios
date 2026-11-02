import SwiftData
import XCTest
@testable import Pocket

/// Storing a tap-through on the song (ADR 0281 D3–D5), and a typed tempo replacing it. `@Model`s are
/// used uninserted, as in `DownbeatCorrectionTests`, never saved.
@MainActor
final class TapThroughCommitTests: XCTestCase {

    /// Six taps at 120 BPM from 2 s, a little uneven, as a hand taps.
    private let taps: [TimeInterval] = [2.0, 2.51, 3.0, 3.49, 4.0, 4.5]

    private func makeModel(downbeat: TimeInterval?) throws -> WaveformPracticeModel {
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self,
            configurations: .init(isStoredInMemoryOnly: true))
        let song = Song.sample()
        song.preciseBPM = 60
        song.bpm = 60
        song.downbeatSeconds = downbeat
        return WaveformPracticeModel(song: song, context: container.mainContext)
    }

    func testATapThroughStoresTheBeatsAndTheirMedian() throws {
        let model = try makeModel(downbeat: nil)
        model.settingBPM = true
        XCTAssertTrue(model.commitBeatMap(taps: taps, onsets: nil))
        XCTAssertEqual(model.song.beatTimes, taps)
        XCTAssertEqual(try XCTUnwrap(model.song.preciseBPM), 120, accuracy: 1e-6)
        XCTAssertEqual(model.song.bpm, 120)
        XCTAssertFalse(model.settingBPM, "the tempo sheet closes")
    }

    /// The screen asks a song with no 1 to start on one.
    func testWithNoOneTheFirstTapIsTheOne() throws {
        let model = try makeModel(downbeat: nil)
        model.commitBeatMap(taps: taps, onsets: nil)
        XCTAssertEqual(model.song.downbeatSeconds, 2.0)
    }

    func testTheOneStaysAndMovesOntoItsBeat() throws {
        let model = try makeModel(downbeat: 3.04)
        model.commitBeatMap(taps: taps, onsets: nil)
        XCTAssertEqual(model.song.downbeatSeconds, 3.0)
    }

    /// A 1 placed before the tapping started lands on a beat carried back from the map.
    func testAOneBeforeTheTapsLandsOnACarriedBeat() throws {
        let model = try makeModel(downbeat: 1.03)
        model.commitBeatMap(taps: taps, onsets: nil)
        XCTAssertEqual(try XCTUnwrap(model.song.downbeatSeconds), 1.0, accuracy: 1e-6)
    }

    func testTapsSnapOntoClearHits() throws {
        let model = try makeModel(downbeat: nil)
        var values = [Double](repeating: 0.1, count: 3_000)
        values[302] = 1.0                                     // a hit at 3.02 s, near the tap at 3.0
        model.commitBeatMap(taps: taps, onsets: BeatMap.Onsets(values: values, framesPerSecond: 100))
        XCTAssertEqual(model.song.beatTimes[2], 3.02, accuracy: 1e-9)
    }

    func testTooFewTapsChangeNothing() throws {
        let model = try makeModel(downbeat: 1)
        XCTAssertFalse(model.commitBeatMap(taps: [2, 2.5, 3], onsets: nil))
        XCTAssertEqual(model.song.beatTimes, [])
        XCTAssertEqual(model.song.preciseBPM, 60)
        XCTAssertNil(model.undoToast)
    }

    func testATapThroughIsUndoable() throws {
        let model = try makeModel(downbeat: 1.25)
        model.commitBeatMap(taps: taps, onsets: nil)
        try XCTUnwrap(model.undoToast).undo()
        XCTAssertEqual(model.song.beatTimes, [])
        XCTAssertEqual(model.song.preciseBPM, 60)
        XCTAssertEqual(model.song.bpm, 60)
        XCTAssertEqual(model.song.downbeatSeconds, 1.25)
    }

    /// D4: a tempo given as a number means one steady tempo.
    func testATypedTempoReplacesTheMapAndCanBeUndone() throws {
        let model = try makeModel(downbeat: nil)
        model.commitBeatMap(taps: taps, onsets: nil)
        model.commitTempo(bpm: 100, downbeat: nil)
        XCTAssertEqual(model.song.beatTimes, [])
        XCTAssertEqual(model.song.preciseBPM, 100)
        try XCTUnwrap(model.undoToast).undo()
        XCTAssertEqual(model.song.beatTimes, taps)
        XCTAssertEqual(try XCTUnwrap(model.song.preciseBPM), 120, accuracy: 1e-6)
    }

    /// Unchanged for a song without a map: a tempo commit offers no undo, as before ADR 0281.
    func testATempoWithoutAMapOffersNoUndo() throws {
        let model = try makeModel(downbeat: nil)
        model.commitTempo(bpm: 100, downbeat: nil)
        XCTAssertNil(model.undoToast)
    }

    func testUseOneTempoKeepsTheMedian() throws {
        let model = try makeModel(downbeat: nil)
        model.commitBeatMap(taps: taps, onsets: nil)
        model.clearBeatMap()
        XCTAssertEqual(model.song.beatTimes, [])
        XCTAssertEqual(try XCTUnwrap(model.song.preciseBPM), 120, accuracy: 1e-6)
        XCTAssertEqual(model.song.downbeatSeconds, 2.0)
    }

    /// The ADR 0153 trap: a new map with the same tempo and 1 must still miss the memoised grid.
    func testTheGridCacheMissesOnANewMap() throws {
        let model = try makeModel(downbeat: 2.0)
        let straight = model.beatGrid
        model.song.beatTimes = taps
        let mapped = model.beatGrid
        XCTAssertNotEqual(straight, mapped)
        let seconds = mapped.map { $0.fraction * model.duration }
        XCTAssertTrue(seconds.contains { abs($0 - 2.51) < 1e-6 }, "the grid has the tapped beat")
    }
}
