import SwiftData
import XCTest
@testable import Pocket

/// Seek-release snap candidate selection (ADR 0080): a **tap** release catches the full
/// candidate set (markers + loop edges + beats), while a **scrub** release drops the dense
/// beat grid and catches only the sparse landmarks — the same set the minimap uses — so a
/// deliberate scrub between beats lands where the finger lifts. These exercise the pure
/// candidate math on the model; the `@Model` objects are used uninserted (à la
/// `WaveformPracticeSpeedTests`), never saved. Main-actor: the model is `@MainActor`.
@MainActor
final class WaveformSeekSnapTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self,
            configurations: .init(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    /// A sample song with a populated beat grid — `bpm` is set, so all it needs is a
    /// downbeat to anchor the pulse.
    private func makeModel() throws -> WaveformPracticeModel {
        let song = Song.sample()
        song.downbeatSeconds = 0               // anchor the grid so `beatGrid` is non-empty
        let model = WaveformPracticeModel(song: song, context: try makeContext())
        XCTAssertFalse(model.beatGrid.isEmpty, "sample must have a beat grid for these tests")
        return model
    }

    func testScrubCandidatesAreLandmarksOnly() throws {
        let model = try makeModel()
        let landmarks = model.landmarkCandidates()
        let scrub = model.snapCandidates(includingBeats: false)
        XCTAssertEqual(scrub.sorted(), landmarks.sorted(),
                       "a scrub release drops the beat grid — candidates are just landmarks")
        // The two sample markers (8s, 22s of 30s) and the four saved-loop edges, no beats.
        XCTAssertEqual(scrub.count, 6)
    }

    func testTapCandidatesAddTheBeatGrid() throws {
        let model = try makeModel()
        let tap = model.snapCandidates(includingBeats: true)
        let scrub = model.snapCandidates(includingBeats: false)
        XCTAssertEqual(tap.count, scrub.count + model.beatGrid.count,
                       "a tap release layers every beat on top of the landmarks")
        for beat in model.beatGrid.map(\.fraction) {
            XCTAssertTrue(tap.contains(beat))
            XCTAssertFalse(scrub.contains(beat), "no beat fraction survives on a scrub release")
        }
    }

    /// The behavioural payoff: a point sitting on a beat but away from every landmark is
    /// caught by a tap release, yet a scrub release lands raw (no catch).
    func testScrubReleaseBetweenLandmarksDoesNotCatchTheBeat() throws {
        let model = try makeModel()
        let landmarks = model.landmarkCandidates()
        let tolerance = model.snapTolerance
        // A beat far enough from any landmark that only the beat grid could catch it.
        let isolatedBeat = try XCTUnwrap(
            model.beatGrid.map(\.fraction).first { beat in
                landmarks.allSatisfy { abs($0 - beat) > tolerance }
            },
            "sample grid should have a beat clear of every landmark")

        XCTAssertEqual(
            WaveformGesture.snap(isolatedBeat, to: model.snapCandidates(includingBeats: true),
                                 tolerance: tolerance),
            isolatedBeat, "a tap release magnetizes to the beat")
        XCTAssertNil(
            WaveformGesture.snap(isolatedBeat, to: model.snapCandidates(includingBeats: false),
                                 tolerance: tolerance),
            "a scrub release lands where the finger lifts — no beat catch")
    }
}
