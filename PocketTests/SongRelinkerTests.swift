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
        // Worth warning about for the same reason as the longer case — hence the absolute
        // difference — but *not* because loops stop playing. See the rescale test below for what
        // actually happens to them.
        XCTAssertTrue(outcome(from: 313, to: 120).durationChangedMaterially)
    }

    func testTheThresholdIsSymmetric() {
        XCTAssertEqual(outcome(from: 313, to: 316).durationChangedMaterially,
                       outcome(from: 316, to: 313).durationChangedMaterially)
    }

    /// **What a shorter file really does to a loop** (re-diagnosed 2026-08-12).
    ///
    /// ADR 0152 §4 and this file both used to say loops "beyond the new end won't play". They
    /// can't be beyond it: `Loop.start`/`.end` are **fractions of the song**, and `apply` refreshes
    /// `song.duration` from the new file — so every loop **rescales** proportionally and stays
    /// inside the audio. The cost is musical (the loop now covers different bars), never silence,
    /// which is why no "out of range" loop state was built. Guard this: a future change storing
    /// loop bounds in seconds would reintroduce exactly the failure the ADR imagined.
    func testAShorterFileRescalesLoopsRatherThanStrandingThem() {
        let song = Song(title: "Take Five", duration: 313,
                        ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        let loop = Loop(name: "head", start: 0.8, end: 0.9, speed: 1, repeats: 1)
        loop.song = song
        XCTAssertEqual(loop.startSeconds, 250.4, accuracy: 0.001)

        song.duration = 120                      // relinked to a materially shorter file
        XCTAssertEqual(loop.startSeconds, 96, accuracy: 0.001)
        XCTAssertEqual(loop.endSeconds, 108, accuracy: 0.001)
        XCTAssertLessThanOrEqual(loop.endSeconds, song.duration,
                                 "a fraction of a refreshed duration is inside the file by construction")
    }
}
