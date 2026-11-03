import SwiftData
import XCTest
@testable import Pocket

/// The click inside the tempo sheet (ADR 0283 D1): it plays the sheet's values before Done, the
/// song's own click comes back on any other way out, and Done keeps the switch. `@Model`s are used
/// uninserted, as in `TapThroughCommitTests`, never saved.
@MainActor
final class TempoSheetClickTests: XCTestCase {

    private func makeModel(bpm: Double? = 120, downbeat: TimeInterval? = 0.5,
                           map: [TimeInterval] = []) throws -> WaveformPracticeModel {
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self,
            configurations: .init(isStoredInMemoryOnly: true))
        let song = Song.sample()
        song.preciseBPM = bpm
        song.bpm = bpm.map { Int($0.rounded()) }
        song.downbeatSeconds = downbeat
        song.extraDownbeatSeconds = downbeat == nil ? [] : [12.1]
        song.beatTimes = map
        return WaveformPracticeModel(song: song, context: container.mainContext)
    }

    /// The click's grid, as the engine holds it.
    private func clicks(_ model: WaveformPracticeModel) -> [TimeInterval] {
        model.engine.metronomeBeats.map { $0.time }
    }

    // MARK: The preview is what Done keeps

    /// Each case previews some values, commits the same, and compares: a tempo, a 1, the bar, and
    /// "leave it" for each, on one tempo and on a beat map.
    func testThePreviewIsTheGridDoneKeeps() throws {
        let map: [TimeInterval] = [0.5, 1.0, 1.6, 2.1, 2.8, 3.3, 3.9]
        let cases: [(TempoClickHooks.Values, map: [TimeInterval])] = [
            (.init(isOn: true, bpm: 100, downbeat: 1.0, beatsPerBar: 3), []),
            (.init(isOn: true, bpm: nil, downbeat: 1.0, beatsPerBar: 4), []),
            (.init(isOn: true, bpm: 100, downbeat: nil, beatsPerBar: 4), []),
            (.init(isOn: true, bpm: nil, downbeat: nil, beatsPerBar: 6), []),
            (.init(isOn: true, bpm: nil, downbeat: 1.6, beatsPerBar: 4), map),
            (.init(isOn: true, bpm: 90, downbeat: 2.0, beatsPerBar: 4), map),
            (.init(isOn: true, bpm: nil, downbeat: nil, beatsPerBar: 3), map)
        ]
        for (index, (value, map)) in cases.enumerated() {
            let model = try makeModel(map: map)
            let preview = model.gridIfCommitted(bpm: value.bpm, downbeat: value.downbeat,
                                                beatsPerBar: value.beatsPerBar)
            model.commitTempo(bpm: value.bpm, downbeat: value.downbeat, beatsPerBar: value.beatsPerBar)
            XCTAssertFalse(preview.isEmpty, "case \(index) has a grid to compare")
            XCTAssertEqual(preview, model.beatGrid, "case \(index)")
        }
    }

    // MARK: The song's click until Done

    func testThePreviewLeavesTheSongsClickAlone() throws {
        let model = try makeModel()
        model.previewClick(.init(isOn: true, bpm: 100, downbeat: 1.0, beatsPerBar: 3))
        XCTAssertTrue(model.engine.metronomeOn, "the sheet's click plays")
        XCTAssertFalse(model.metronomeOn, "the song's click is still off")
        XCTAssertEqual(try XCTUnwrap(clicks(model).first(where: { $0 >= 1.0 })), 1.0, accuracy: 1e-9)
    }

    /// Cancel, a swipe down, or Set the 1 on the waveform: the click and its grid go back.
    func testAnyOtherWayOutPutsTheSongsClickBack() throws {
        let model = try makeModel()
        let songClicks = model.beatGrid.map { $0.fraction * model.duration }
        model.previewClick(.init(isOn: true, bpm: 100, downbeat: 1.0, beatsPerBar: 3))
        model.endClickPreview(keepOn: nil)
        XCTAssertFalse(model.engine.metronomeOn)
        XCTAssertFalse(model.metronomeOn)
        XCTAssertEqual(clicks(model), songClicks)
    }

    func testAnOnClickStaysOnWhenTheSheetIsCancelled() throws {
        let model = try makeModel()
        model.toggleMetronome()
        model.previewClick(.init(isOn: false, bpm: nil, downbeat: nil, beatsPerBar: 4))
        XCTAssertFalse(model.engine.metronomeOn, "the sheet's switch stops it")
        model.endClickPreview(keepOn: nil)
        XCTAssertTrue(model.metronomeOn)
        XCTAssertTrue(model.engine.metronomeOn)
    }

    func testDoneKeepsTheSwitch() throws {
        let model = try makeModel()
        model.endClickPreview(keepOn: true)
        XCTAssertTrue(model.metronomeOn)
        XCTAssertTrue(model.engine.metronomeOn)

        model.endClickPreview(keepOn: false)
        XCTAssertFalse(model.metronomeOn)
        XCTAssertFalse(model.engine.metronomeOn)
    }

    /// No 1, no grid, so nothing to click: Done can't leave the song's click on over silence.
    func testDoneCantKeepAClickWithNoGrid() throws {
        let model = try makeModel(downbeat: nil)
        model.endClickPreview(keepOn: true)
        XCTAssertFalse(model.metronomeOn)
        XCTAssertFalse(model.engine.metronomeOn)
    }
}
