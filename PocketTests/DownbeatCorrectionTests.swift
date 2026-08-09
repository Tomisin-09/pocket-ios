import SwiftData
import XCTest
@testable import Pocket

/// Re-anchoring the beat grid (ADR 0154). One tempo and one 1 draw a straight line, which is
/// wrong for music whose pulse moves; a correction restarts the grid from where it's dropped.
/// The rules that decide *which* anchor a drop becomes are the part that breaks silently, so
/// they're pinned here. `@Model`s are used uninserted (à la `WaveformGridStateTests`), never saved.
@MainActor
final class DownbeatCorrectionTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self,
            configurations: .init(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    /// 60 BPM ⇒ a one-second beat, so "half a beat" in these tests is 0.5 s.
    private func makeModel(downbeat: TimeInterval?) throws -> WaveformPracticeModel {
        let song = Song.sample()
        song.preciseBPM = 60
        song.bpm = 60
        song.downbeatSeconds = downbeat
        return WaveformPracticeModel(song: song, context: try makeContext())
    }

    // MARK: the model

    func testAnchorsAreEmptyWithoutAPrimary() throws {
        let song = Song.sample()
        song.downbeatSeconds = nil
        // A correction with no primary is meaningless — it must not grid the song on its own.
        song.extraDownbeatSeconds = [4]
        XCTAssertTrue(song.downbeatAnchors.isEmpty)
    }

    func testAnchorsCombineThePrimaryAndCorrectionsInTimeOrder() throws {
        let song = Song.sample()
        song.downbeatSeconds = 2
        song.extraDownbeatSeconds = [9, 5]
        XCTAssertEqual(song.downbeatAnchors, [2, 5, 9])
    }

    func testASongWithNoCorrectionsIsUnchanged() throws {
        let song = Song.sample()
        song.downbeatSeconds = 1.25
        XCTAssertEqual(song.extraDownbeatSeconds, [])
        XCTAssertEqual(song.downbeatAnchors, [1.25])
    }

    // MARK: which anchor a drop becomes

    /// The first 1 on a song with no anchor is the primary, not a correction.
    func testConfirmingWithNoAnchorSetsThePrimary() throws {
        let model = try makeModel(downbeat: nil)
        model.downbeatDraft = 4 / model.duration
        model.confirmDownbeat()
        XCTAssertEqual(try XCTUnwrap(model.song.downbeatSeconds), 4, accuracy: 1e-6)
        XCTAssertTrue(model.song.extraDownbeatSeconds.isEmpty)
    }

    /// The point of the feature: with a 1 already placed, ✓ leaves it alone and corrects onward.
    func testConfirmingWithAnAnchorAddsACorrection() throws {
        let model = try makeModel(downbeat: 0)
        model.downbeatDraft = 20 / model.duration
        model.confirmDownbeat()
        XCTAssertEqual(try XCTUnwrap(model.song.downbeatSeconds), 0, accuracy: 1e-6)
        XCTAssertEqual(model.song.extraDownbeatSeconds.count, 1)
        XCTAssertEqual(model.song.extraDownbeatSeconds[0], 20, accuracy: 1e-6)
    }

    /// "Move the 1" is the other intent: replace the original, leave corrections where they are —
    /// they're anchored to their own sections and are still right.
    func testMovingReplacesThePrimaryAndKeepsCorrections() throws {
        let model = try makeModel(downbeat: 0)
        model.song.extraDownbeatSeconds = [20]
        model.downbeatDraft = 3 / model.duration
        model.moveDownbeat()
        XCTAssertEqual(try XCTUnwrap(model.song.downbeatSeconds), 3, accuracy: 1e-6)
        XCTAssertEqual(model.song.extraDownbeatSeconds, [20])
    }

    /// A drop within half a beat of the primary is a nudge to *it*, not a new anchor — two
    /// anchors that close can't both be a 1, and `BeatGrid` would discard the second anyway.
    func testADropOnTopOfThePrimaryNudgesItInstead() throws {
        let model = try makeModel(downbeat: 4)
        model.addDownbeatCorrection(at: 4.2)
        XCTAssertEqual(try XCTUnwrap(model.song.downbeatSeconds), 4.2, accuracy: 1e-6)
        XCTAssertTrue(model.song.extraDownbeatSeconds.isEmpty)
    }

    func testADropOnTopOfACorrectionNudgesThatCorrection() throws {
        let model = try makeModel(downbeat: 0)
        model.song.extraDownbeatSeconds = [20]
        model.addDownbeatCorrection(at: 20.3)
        XCTAssertEqual(model.song.extraDownbeatSeconds.count, 1)
        XCTAssertEqual(model.song.extraDownbeatSeconds[0], 20.3, accuracy: 1e-6)
    }

    /// Just past half a beat is a genuinely different place, so it's a new correction.
    func testADropBeyondHalfABeatIsANewCorrection() throws {
        let model = try makeModel(downbeat: 4)
        model.addDownbeatCorrection(at: 4.6)
        XCTAssertEqual(try XCTUnwrap(model.song.downbeatSeconds), 4, accuracy: 1e-6)
        XCTAssertEqual(model.song.extraDownbeatSeconds.count, 1)
    }

    func testCorrectionsAreKeptInTimeOrder() throws {
        let model = try makeModel(downbeat: 0)
        model.addDownbeatCorrection(at: 30)
        model.addDownbeatCorrection(at: 10)
        model.addDownbeatCorrection(at: 20)
        XCTAssertEqual(model.song.extraDownbeatSeconds, [10, 20, 30])
    }

    // MARK: removal

    func testClearingRemovesEveryCorrectionButNotThePrimary() throws {
        let model = try makeModel(downbeat: 2)
        model.song.extraDownbeatSeconds = [10, 20]
        model.clearDownbeatCorrections()
        XCTAssertTrue(model.song.extraDownbeatSeconds.isEmpty)
        XCTAssertEqual(try XCTUnwrap(model.song.downbeatSeconds), 2, accuracy: 1e-6)
    }

    /// Clearing is undoable, which is what makes a single clear-all an honest removal path
    /// rather than a way to lose work.
    func testClearingIsUndoable() throws {
        let model = try makeModel(downbeat: 2)
        model.song.extraDownbeatSeconds = [10, 20]
        model.clearDownbeatCorrections()
        let toast = try XCTUnwrap(model.undoToast)
        toast.undo()
        XCTAssertEqual(model.song.extraDownbeatSeconds, [10, 20])
    }

    func testClearingWithNoCorrectionsDoesNothing() throws {
        let model = try makeModel(downbeat: 2)
        model.clearDownbeatCorrections()
        XCTAssertNil(model.undoToast, "nothing was removed, so nothing should offer an undo")
    }

    // MARK: the grid it produces

    /// End to end: a correction changes the grid the waveform and the click both read.
    func testACorrectionReanchorsTheGrid() throws {
        let model = try makeModel(downbeat: 0)
        let before = model.beatGrid
        model.addDownbeatCorrection(at: 20.5)
        let after = model.beatGrid
        XCTAssertNotEqual(before, after, "the memoised grid must miss its cache on a new anchor")
        let fractions = after.map { $0.fraction * model.duration }
        XCTAssertTrue(fractions.contains { abs($0 - 20.5) < 1e-6 },
                      "the correction's own beat should be in the grid")
    }
}
