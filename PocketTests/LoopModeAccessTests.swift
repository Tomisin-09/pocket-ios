import XCTest
@testable import Pocket

/// **Each mode gates on what it needs** (ADR 0138).
///
/// One test — `commandTempo != nil` — was written for the trainer and then inherited by every mode
/// that came after it. That put **ear training** behind a measurement you can only make by playing
/// the passage on your instrument, which is the one thing ear training exists not to require.
///
/// These preconditions fail *silently* in both directions: too strict and a mode that would run is
/// hidden, too loose and a row offers a block that can't play. Neither throws, so they are asserted
/// here rather than eyeballed on the add sheet.
final class LoopModeAccessTests: XCTestCase {

    private func facts(measured: Bool, audible: Bool) -> LoopModeAccess.Facts {
        LoopModeAccess.Facts(hasCommandTempo: measured, audioResolves: audible)
    }

    private func makeLoop(measured: Bool, source: SongRef.Source? = .localFile) -> Loop {
        let loop = Loop(name: "Chorus lick", start: 0.1, end: 0.2, speed: 0.8, repeats: 3)
        if measured { loop.commandTempo = 0.8 }
        if let source {
            loop.song = Song(title: "Test", duration: 120,
                             ref: SongRef(id: "s1", source: source, bookmark: nil))
        }
        return loop
    }

    // MARK: - The trainer is unchanged

    func testTrainerRequiresACommandTempo() {
        // The ramp is anchored on it — nothing to build a staircase around without one. This rule is
        // the one thing ADR 0138 does *not* change.
        XCTAssertTrue(LoopModeAccess.allows(.trainer, facts(measured: true, audible: true)))
        XCTAssertFalse(LoopModeAccess.allows(.trainer, facts(measured: false, audible: true)))
    }

    // MARK: - Ear training, which is the fix

    func testEarTrainingDoesNotRequireACommandTempo() {
        // The inversion this ADR exists to undo: the mode you can do with no instrument in hand was
        // gated behind having already played the passage on your instrument.
        XCTAssertTrue(LoopModeAccess.allows(.ear, facts(measured: false, audible: true)))
    }

    func testEarTrainingRequiresAudioItCanActuallyPlay() {
        // If it can be heard it can be sung back — and if it can't, there is nothing to sing back.
        XCTAssertFalse(LoopModeAccess.allows(.ear, facts(measured: true, audible: false)))
    }

    func testALoopWithNoSongResolvesNoAudio() {
        // Hence `audioResolves` rather than a `song != nil` check: no song means no sound.
        XCTAssertFalse(LoopModeAccess.Facts(makeLoop(measured: true, source: nil)).audioResolves)
        XCTAssertFalse(LoopModeAccess.allows(.ear, makeLoop(measured: true, source: nil)))
    }

    func testAnAppleMusicBackedLoopResolvesNoAudio() {
        // ADR 0001 — catalog audio is browse/metadata only and can't be played back or stretched, the
        // same condition the Songs bucket already applies via `playableSongs`.
        XCTAssertFalse(LoopModeAccess.allows(.ear, makeLoop(measured: true, source: .appleMusic)))
    }

    // MARK: - What a row offers

    func testAMeasuredLocalLoopOffersBothModes() {
        XCTAssertEqual(LoopModeAccess.modes(for: makeLoop(measured: true)), [.trainer, .ear])
    }

    func testAnUnmeasuredLocalLoopOffersEarTrainingOnly() {
        // The whole point: this loop is reachable and useful, where before it was hidden entirely.
        XCTAssertEqual(LoopModeAccess.modes(for: makeLoop(measured: false)), [.ear])
    }

    func testALoopWithNoSongAndNoTempoOffersNothing() {
        let loop = makeLoop(measured: false, source: nil)
        XCTAssertTrue(LoopModeAccess.modes(for: loop).isEmpty)
    }

    func testEveryModeIsGatedOnSomething() {
        // Guards the direction that would quietly undo this: a mode added later and left ungated
        // would pass every loop. `allows` is exhaustive over `LoopRunMode` with no `default`, so a
        // new case can't compile without stating its precondition — this asserts the same property
        // for the cases that exist.
        let nothing = facts(measured: false, audible: false)
        for mode in LoopRunMode.allCases {
            XCTAssertFalse(LoopModeAccess.allows(mode, nothing),
                           "\(mode) admits a loop with no tempo and no audio")
        }
    }
}
