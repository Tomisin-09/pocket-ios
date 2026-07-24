import XCTest
@testable import Pocket

/// Pure frequency → note mapping for the tuner (ADR 0115). The Hz→note→cents math and the tunable A
/// reference are UI-free, so they're pinned here.
final class TunerReadingTests: XCTestCase {

    // MARK: exact notes

    func testConcertA_IsA4WithZeroCents() throws {
        let reading = try XCTUnwrap(TunerReading.nearest(toFrequency: 440))
        XCTAssertEqual(reading.midiNote, 69)
        XCTAssertEqual(reading.noteName, "A")
        XCTAssertEqual(reading.octave, 4)
        XCTAssertEqual(reading.cents, 0, accuracy: 0.001)
        XCTAssertTrue(reading.isInTune)
        XCTAssertEqual(reading.pitchLabel, "A4")
    }

    /// One open-string expectation — a named struct instead of a 3-tuple (SwiftLint large_tuple).
    private struct OpenString { let frequency: Double; let note: String; let octave: Int }

    func testGuitarOpenStringsNameCorrectly() throws {
        // E2 A2 D3 G3 B3 E4.
        let cases = [
            OpenString(frequency: 82.41, note: "E", octave: 2),
            OpenString(frequency: 110.0, note: "A", octave: 2),
            OpenString(frequency: 146.83, note: "D", octave: 3),
            OpenString(frequency: 196.0, note: "G", octave: 3),
            OpenString(frequency: 246.94, note: "B", octave: 3),
            OpenString(frequency: 329.63, note: "E", octave: 4)
        ]
        for expected in cases {
            let reading = try XCTUnwrap(TunerReading.nearest(toFrequency: expected.frequency))
            XCTAssertEqual(reading.noteName, expected.note, "\(expected.frequency) Hz")
            XCTAssertEqual(reading.octave, expected.octave, "\(expected.frequency) Hz")
            XCTAssertLessThan(abs(reading.cents), 5, "\(expected.frequency) Hz should read in tune")
        }
    }

    // MARK: cents sign & tolerance

    func testFlatIsNegativeSharpIsPositive() throws {
        // 15 cents below and above A4 (440 · 2^(±0.15/12)).
        let flat = try XCTUnwrap(TunerReading.nearest(toFrequency: 440 * pow(2, -0.15 / 12)))
        let sharp = try XCTUnwrap(TunerReading.nearest(toFrequency: 440 * pow(2, 0.15 / 12)))
        XCTAssertEqual(flat.midiNote, 69)
        XCTAssertEqual(sharp.midiNote, 69)
        XCTAssertEqual(flat.cents, -15, accuracy: 0.01)
        XCTAssertEqual(sharp.cents, 15, accuracy: 0.01)
        XCTAssertFalse(flat.isInTune)
        XCTAssertFalse(sharp.isInTune)
    }

    func testInTuneToleranceBoundary() throws {
        let atEdge = try XCTUnwrap(TunerReading.nearest(toFrequency: 440 * pow(2, 0.05 / 12)))  // +5¢
        let justOver = try XCTUnwrap(TunerReading.nearest(toFrequency: 440 * pow(2, 0.06 / 12))) // +6¢
        XCTAssertTrue(atEdge.isInTune)
        XCTAssertFalse(justOver.isInTune)
    }

    func testCentsAlwaysWithinHalfSemitone() throws {
        // Sweep across a semitone boundary; cents must always stay in −50…+50.
        for step in stride(from: 0.0, through: 200.0, by: 7.0) {
            let reading = try XCTUnwrap(TunerReading.nearest(toFrequency: 440 * pow(2, step / 1_200)))
            XCTAssertLessThanOrEqual(reading.cents, 50)
            XCTAssertGreaterThanOrEqual(reading.cents, -50)
        }
    }

    // MARK: calibration

    func testReferencePitchCalibrationShiftsResult() throws {
        // With A=432, a 432 Hz tone is A4/0¢; the default A=440 reads it flat instead.
        let calibrated = try XCTUnwrap(TunerReading.nearest(toFrequency: 432, referenceA: 432))
        XCTAssertEqual(calibrated.noteName, "A")
        XCTAssertEqual(calibrated.octave, 4)
        XCTAssertEqual(calibrated.cents, 0, accuracy: 0.001)

        let atA440 = try XCTUnwrap(TunerReading.nearest(toFrequency: 432, referenceA: 440))
        XCTAssertLessThan(atA440.cents, -20)   // ~−32¢ flat of A at concert pitch
    }

    // MARK: guards

    func testNonPositiveInputsReturnNil() {
        XCTAssertNil(TunerReading.nearest(toFrequency: 0))
        XCTAssertNil(TunerReading.nearest(toFrequency: -100))
        XCTAssertNil(TunerReading.nearest(toFrequency: 440, referenceA: 0))
    }
}
