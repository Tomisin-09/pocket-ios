import XCTest
@testable import Pocket

/// The one piece of relink logic that is pure and can rot silently (ADR 0148 §6): deciding whether
/// the file the player picked is *the same recording* as the one their loops were drawn against.
///
/// Everything else in `SongRelinker` is I/O — decoding a real audio file and writing to a
/// `ModelContext` — and is covered where it can be: `SongFileStoreTests` pins that adopting twice
/// for one `sourceID` replaces rather than accumulates, which is what makes a relink repair a song
/// instead of leaving a second orphaned copy behind, and `SongAudioResolverTests` pins that the
/// `sourceID` loops hang off never moves.
final class SongRelinkerTests: XCTestCase {

    private func outcome(from previous: TimeInterval, to new: TimeInterval) -> SongRelinker.Outcome {
        SongRelinker.Outcome(newDuration: new, previousDuration: previous)
    }

    func testAnIdenticalLengthIsNotAMismatch() {
        XCTAssertFalse(outcome(from: 313, to: 313).durationChangedMaterially)
    }

    func testAReEncodeOfTheSameTrackIsNotAMismatch() {
        // Re-encoding shifts the length by a fraction of a second; the loops still line up, and
        // warning here would train the player to dismiss the warning that matters.
        XCTAssertFalse(outcome(from: 313, to: 313.4).durationChangedMaterially)
        XCTAssertFalse(outcome(from: 313, to: 312.6).durationChangedMaterially)
    }

    func testAMateriallyLongerFileIsAMismatch() {
        XCTAssertTrue(outcome(from: 313, to: 402).durationChangedMaterially)
    }

    func testAMateriallyShorterFileIsAMismatch() {
        // The dangerous direction: loops past the new end simply won't play, so this must warn
        // just as loudly as the longer case — hence the absolute difference.
        XCTAssertTrue(outcome(from: 313, to: 120).durationChangedMaterially)
    }

    func testTheThresholdIsSymmetric() {
        XCTAssertEqual(outcome(from: 313, to: 316).durationChangedMaterially,
                       outcome(from: 316, to: 313).durationChangedMaterially)
    }
}
