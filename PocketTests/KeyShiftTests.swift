import XCTest
@testable import Pocket

/// **Another key** (ADR 0305): the clamps that keep the audio within six semitones of the recording, and
/// what Active listening says about the key you're hearing. Every line is a sentence the player reads,
/// and a wrong spelling (*A♯ minor*) or a wrong direction still renders, so they're pinned here.
final class KeyShiftTests: XCTestCase {

    // MARK: - The clamps (D2)

    func testTheTotalNeverGoesMoreThanSixFromTheRecording() {
        XCTAssertEqual(KeyShift.total(song: 0, session: 3), 3)
        XCTAssertEqual(KeyShift.total(song: 0, session: 9), 6)
        XCTAssertEqual(KeyShift.total(song: 0, session: -9), -6)
        XCTAssertEqual(KeyShift.total(song: 1, session: 6), 6, "a song raised 1 plus 6 is still 6")
        XCTAssertEqual(KeyShift.total(song: 1, session: -7), -6)
        XCTAssertEqual(KeyShift.total(song: 9, session: 0), 6, "a song's own shift is held too")
    }

    /// With the song raised by 1 the stepper runs −7…+5: still twelve keys, never past six in total.
    func testTheSessionRangeAlwaysReachesTwelveKeys() {
        XCTAssertEqual(KeyShift.sessionRange(song: 0), -6...6)
        XCTAssertEqual(KeyShift.sessionRange(song: 1), -7...5)
        XCTAssertEqual(KeyShift.sessionRange(song: -2), -4...8)
        for song in -6...6 {
            XCTAssertEqual(KeyShift.sessionRange(song: song).count, 13)
        }
        XCTAssertEqual(KeyShift.session(9, song: 0), 6)
        XCTAssertEqual(KeyShift.session(-7, song: 1), -7)
        XCTAssertEqual(KeyShift.session(6, song: 1), 5)
    }

    func testTheStepperReadsSignedWithARealMinus() {
        XCTAssertEqual(KeyShift.stepperValue(3), "+3")
        XCTAssertEqual(KeyShift.stepperValue(-3), "−3")
        XCTAssertEqual(KeyShift.stepperValue(0), "0")
    }

    // MARK: - The key you're hearing (D3)

    func testTheLineAtZeroSaysAsRecorded() {
        XCTAssertEqual(HeardKey(recording: .gMinor, shift: 0).line, "G minor, as recorded")
        XCTAssertEqual(HeardKey(recording: .unknown, shift: 0).line, "As recorded")
        XCTAssertFalse(HeardKey(recording: .gMinor, shift: 0).isShifted)
    }

    /// The mockup's line, spelled key-first: G minor up 3 is B♭ minor, never A♯ minor (ADR 0123).
    func testTheLineSpellsTheHeardKeyKeyFirst() {
        XCTAssertEqual(HeardKey(recording: .gMinor, shift: 3).line, "B♭ minor · 3 up")
        XCTAssertEqual(HeardKey(recording: .gMinor, shift: -2).line, "F minor · 2 down")
        XCTAssertEqual(HeardKey(recording: .eMajor, shift: -1).line, "E♭ major · 1 down")
        XCTAssertEqual(HeardKey(recording: .aMajor, shift: 1).heard, .aSharpMajor)
        XCTAssertEqual(HeardKey(recording: .bMajor, shift: 1).heard, .cMajor, "wraps past B")
    }

    /// Six up and six down land on the same key, and the line says so.
    func testAtSixTheLineSaysTheOtherWayIsTheSameKey() {
        XCTAssertEqual(HeardKey(recording: .gMinor, shift: 6).line, "C♯ minor · 6 up · same key as 6 down")
        XCTAssertEqual(HeardKey(recording: .gMinor, shift: -6).heard, HeardKey(recording: .gMinor, shift: 6).heard)
    }

    func testWithNoKeyTheLineSaysHowFarItMoved() {
        XCTAssertEqual(HeardKey(recording: .unknown, shift: 3).line, "3 semitones up")
        XCTAssertEqual(HeardKey(recording: .unknown, shift: -1).line, "1 semitone down")
        XCTAssertEqual(HeardKey(recording: .unknown, shift: 3).heard, .unknown)
        XCTAssertNil(HeardKey(recording: .unknown, shift: 3).spelling, "falls back to the player's preference")
    }

    /// Names on the sheet are spelled for the key you're hearing: B♭ minor spells flats.
    func testNamesAreSpelledForTheHeardKey() throws {
        let spelling = try XCTUnwrap(HeardKey(recording: .gMinor, shift: 3).spelling)
        XCTAssertEqual(spelling.name(pitchClass: 10), "B♭")
        XCTAssertEqual(spelling.name(pitchClass: 1), "D♭")
    }

    // MARK: - Names at a shift (D5)

    func testTheSavedPieceSaysItsNamesAreHiddenAndWhy() {
        let heard = HeardKey(recording: .gMinor, shift: 3)
        XCTAssertEqual(heard.hiddenNames,
                       "Your names in G minor are hidden while you hear it in B♭ minor. They're the answer.")
        XCTAssertEqual(heard.nameButton, "Name the notes in B♭ minor")
        XCTAssertEqual(heard.notKept, "Names you make in B♭ minor aren't kept. Your names in G minor stay as they "
                       + "are, and your taps carry over.")
        XCTAssertEqual(heard.namingLine, "Naming in B♭ minor · your names in G minor stay as they are")
    }

    func testWithNoKeyTheSameWordsSayHowFarItMoved() {
        let heard = HeardKey(recording: .unknown, shift: -2)
        XCTAssertEqual(heard.hiddenNames, "Your names are hidden while you hear it 2 down. They're the answer.")
        XCTAssertEqual(heard.nameButton, "Name the notes 2 down")
        XCTAssertEqual(heard.notKept, "Names you make 2 down aren't kept. Your saved names stay as they are, "
                       + "and your taps carry over.")
        XCTAssertEqual(heard.namingLine, "Naming 2 down · your saved names stay as they are")
    }
}
