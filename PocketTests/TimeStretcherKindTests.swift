import AVFoundation
import XCTest
@testable import Pocket

/// ADR 0140 §4 adoption — `'tmpt'` is the shipping stretcher, and `.newTimePitch` is a fallback that
/// should never fire. Not a listening test: those were done on the device and the verdict is written
/// into the ADR. This is the part a machine *can* check — that the component the whole decision rests
/// on is actually there, and that a missing one degrades rather than goes silent.
@MainActor
final class TimeStretcherKindTests: XCTestCase {

    func testTheConfiguredStretcherIsTheHighQualityOne() {
        // Not a Debug flag any more. If someone reintroduces a toggle or flips the default back, this
        // fails rather than silently returning the app to the unit the A/B rejected.
        XCTAssertEqual(TimeStretcher.Kind.configured, .highQuality)
    }

    func testTheHighQualityUnitIsActuallyAvailable() {
        // The load-bearing fact. `'tmpt'` is looked up in the component registry, and if it were ever
        // absent every practice session would quietly run the fallback — better than silence, but not
        // what was chosen. Asserting the *resolved* kind (not the requested one) is what makes this
        // meaningful: it goes through the same `AudioComponentFindNext` path the app does.
        XCTAssertEqual(TimeStretcher().kind, .highQuality)
    }

    func testTheFallbackStillBuildsAWorkingStretcher() {
        // The safety net's own test. `.newTimePitch` exists only for an absent `'tmpt'`, so nothing
        // else exercises it — and an untested fallback is a fallback that fails the one time it runs.
        let stretcher = TimeStretcher(kind: .newTimePitch)
        XCTAssertEqual(stretcher.kind, .newTimePitch)
        XCTAssertNotNil(stretcher.node)
    }

    func testBothStretchersClampToTheEnginesRateBounds() {
        // 0.25 sits exactly on `'tmpt'`'s lower boundary (its range is 0.25…4.0), so the clamp is what
        // stands between the product's speed axis and an out-of-range parameter write.
        for kind in [TimeStretcher.Kind.highQuality, .newTimePitch] {
            let stretcher = TimeStretcher(kind: kind)
            XCTAssertEqual(stretcher.setRate(0.05), TimeStretcher.minimumRate)
            XCTAssertEqual(stretcher.setRate(9.0), TimeStretcher.maximumRate)
            XCTAssertEqual(stretcher.setRate(0.5), 0.5)
        }
    }

    func testRateSurvivesAReassert() {
        // `'tmpt'`'s rate is a raw parameter write that predates AU initialisation, which is why
        // `PracticeAudioEngine` re-asserts after `engine.start()`. Re-asserting must not disturb it.
        let stretcher = TimeStretcher()
        stretcher.setRate(0.25)
        stretcher.reassertParameters()
        XCTAssertEqual(stretcher.rate, 0.25)
    }

    // MARK: - Another key (ADR 0305)

    /// The pitch the audio unit itself holds, in cents, read back the way each backend was written.
    private func unitCents(_ stretcher: TimeStretcher) -> Float? {
        if let unit = stretcher.node as? AVAudioUnitTimePitch { return unit.pitch }
        guard let unit = stretcher.node as? AVAudioUnit else { return nil }
        var value: AudioUnitParameterValue = .nan
        let status = AudioUnitGetParameter(unit.audioUnit, kTimePitchParam_Pitch, kAudioUnitScope_Global, 0, &value)
        return status == noErr ? value : nil
    }

    func testANewStretcherIsAtTheRecordingsPitch() {
        for kind in [TimeStretcher.Kind.highQuality, .newTimePitch] {
            let stretcher = TimeStretcher(kind: kind)
            XCTAssertEqual(stretcher.pitchSemitones, 0)
            XCTAssertEqual(unitCents(stretcher), 0)
        }
    }

    /// D2: never more than six from the recording, whatever asks, and the unit holds what was applied.
    func testPitchIsHeldWithinSixAndReachesTheUnitOnBothStretchers() {
        for kind in [TimeStretcher.Kind.highQuality, .newTimePitch] {
            let stretcher = TimeStretcher(kind: kind)
            XCTAssertEqual(stretcher.setPitch(semitones: 3), 3)
            XCTAssertEqual(unitCents(stretcher), 300, "\(kind)")
            XCTAssertEqual(stretcher.setPitch(semitones: 9), 6)
            XCTAssertEqual(unitCents(stretcher), 600, "\(kind)")
            XCTAssertEqual(stretcher.setPitch(semitones: -12), -6)
            XCTAssertEqual(unitCents(stretcher), -600, "\(kind)")
        }
    }

    /// D1: pitch is never tied to speed. Changing one leaves the other where it was.
    func testPitchAndRateDontMoveEachOther() {
        let stretcher = TimeStretcher()
        stretcher.setRate(0.5)
        stretcher.setPitch(semitones: -4)
        XCTAssertEqual(stretcher.rate, 0.5)
        stretcher.setRate(0.25)
        XCTAssertEqual(stretcher.pitchSemitones, -4)
        XCTAssertEqual(unitCents(stretcher), -400)
    }

    func testPitchSurvivesAReassert() {
        let stretcher = TimeStretcher()
        stretcher.setPitch(semitones: 5)
        stretcher.reassertParameters()
        XCTAssertEqual(stretcher.pitchSemitones, 5)
        XCTAssertEqual(unitCents(stretcher), 500)
    }
}
