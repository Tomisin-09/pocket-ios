import XCTest
@testable import Pocket

/// ADR 0140 §5 — the mixer trim that keeps song + click inside full scale, and the click voicing it
/// is derived from. Its own file rather than more of `AudioMathTests`, which is at the type-body cap,
/// and it reads better beside the thing it protects: a clipped peak sounds like a smeared one, so
/// without this the §4 listening test could credit the mixer's fault to the stretcher.
final class HeadroomTrimTests: XCTestCase {

    func testHeadroomTrimLeavesRoomForTheLoudestClickOnAFullScaleSong() {
        // The guarantee, stated as the sum: a full-scale song peak plus a click accent landing on it
        // must not exceed 1.0. If this ever fails, clipping gets credited to the stretcher.
        let trim = Double(AudioMath.headroomTrim(peakClick: ClickTimbre.loudestPeakAmplitude))
        XCTAssertLessThanOrEqual(trim * (1 + ClickTimbre.loudestPeakAmplitude), 1.0 + 1e-6)
    }

    func testHeadroomTrimIsDerivedFromTheClickAndNotPinnedToALiteral() {
        // A 0.7 accent needs 1/1.7; retuning a timbre must move the trim, not silently eat headroom.
        XCTAssertEqual(AudioMath.headroomTrim(peakClick: 0.7), Float(1.0 / 1.7), accuracy: 1e-6)
        XCTAssertEqual(AudioMath.headroomTrim(peakClick: 1.0), 0.5, accuracy: 1e-6)
    }

    func testHeadroomTrimTrimsMoreForALouderClick() {
        XCTAssertLessThan(AudioMath.headroomTrim(peakClick: 0.9),
                          AudioMath.headroomTrim(peakClick: 0.3))
    }

    func testHeadroomTrimIsUnityWhenThereIsNoClickToLeaveRoomFor() {
        XCTAssertEqual(AudioMath.headroomTrim(peakClick: 0), 1)
        XCTAssertEqual(AudioMath.headroomTrim(peakClick: -0.5), 1)
    }

    func testHeadroomTrimStaysAudibleForTheClickWeActuallyShip() {
        // A guard against the guarantee being met by gutting the song: the shipping voicings must not
        // cost more than ~6 dB. If a future timbre pushes past this, the trim is no longer "cheap
        // insurance" and the click needs re-voicing rather than the mix needs re-gaining.
        XCTAssertGreaterThan(AudioMath.headroomTrim(peakClick: ClickTimbre.loudestPeakAmplitude), 0.5)
    }

    func testLoudestClickPeakIsTheAccentOfTheLoudestTimbre() {
        // Sanity-check the input the trim is derived from, so a wrong reading of the voicings can't
        // pass the tests above by agreeing with itself.
        XCTAssertEqual(ClickTimbre.loudestPeakAmplitude, 0.7, accuracy: 1e-9)
        XCTAssertEqual(ClickTimbre.rim.peakAmplitude, 0.7, accuracy: 1e-9)
        XCTAssertEqual(ClickTimbre.click.peakAmplitude, 0.6, accuracy: 1e-9)
    }
}
