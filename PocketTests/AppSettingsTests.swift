import XCTest
@testable import Pocket

/// The default-resolution rule for persisted settings (ADR 0050). `UserDefaults.bool` reads a
/// missing key as `false`, which would silently disable an opt-out setting; `resolvedBool` keeps
/// "never set ⇒ default" honest. Pinned because a regression here flips a feature off without a
/// user ever touching it (AGENTS.md).
final class AppSettingsTests: XCTestCase {

    func testUnsetKeyTakesTheDefault() {
        // The whole point: an untouched setting reads as its default, not `false`.
        XCTAssertTrue(AppSettings.resolvedBool(storedValue: nil, default: true))
        XCTAssertFalse(AppSettings.resolvedBool(storedValue: nil, default: false))
    }

    func testSetKeyReadsItsStoredValue() {
        XCTAssertTrue(AppSettings.resolvedBool(storedValue: true, default: false))
        XCTAssertFalse(AppSettings.resolvedBool(storedValue: false, default: true))
    }

    func testNonBoolStoredValueFallsBackToDefault() {
        // A key that somehow holds a non-Bool can't crash or read arbitrarily — take the default.
        XCTAssertTrue(AppSettings.resolvedBool(storedValue: "yes", default: true))
        XCTAssertFalse(AppSettings.resolvedBool(storedValue: 42, default: false))
    }

    // MARK: integer settings (count-in length)

    func testUnsetIntKeyTakesTheDefault() {
        // Same rule for ints: a missing key is the default, not `UserDefaults.integer`'s 0.
        XCTAssertEqual(AppSettings.resolvedInt(storedValue: nil, default: 1), 1)
        XCTAssertEqual(AppSettings.resolvedInt(storedValue: 2, default: 1), 2)
    }

    func testNonIntStoredValueFallsBackToDefault() {
        XCTAssertEqual(AppSettings.resolvedInt(storedValue: "two", default: 1), 1)
    }

    // MARK: appearance override (ADR 0062 follow-up)

    func testUnsetAppearanceTakesSystem() {
        XCTAssertEqual(AppSettings.resolvedAppearance(storedValue: nil), .system)
    }

    func testSetAppearanceReadsItsStoredValue() {
        XCTAssertEqual(AppSettings.resolvedAppearance(storedValue: "light"), .light)
        XCTAssertEqual(AppSettings.resolvedAppearance(storedValue: "dark"), .dark)
    }

    func testUnrecognisedAppearanceFallsBackToSystem() {
        XCTAssertEqual(AppSettings.resolvedAppearance(storedValue: "sepia"), .system)
    }

    // MARK: tuner settings (ADR 0115 Slice 4)

    func testUnsetTunerInstrumentTakesGuitar() {
        XCTAssertEqual(AppSettings.resolvedInstrument(storedValue: nil), .guitar)
    }

    func testSetTunerInstrumentReadsItsStoredValue() {
        XCTAssertEqual(AppSettings.resolvedInstrument(storedValue: "bass"), .bass)
    }

    func testUnrecognisedTunerInstrumentFallsBackToGuitar() {
        XCTAssertEqual(AppSettings.resolvedInstrument(storedValue: "banjo"), .guitar)
    }

    func testUnsetTunerModeTakesGuided() {
        XCTAssertEqual(AppSettings.resolvedTunerMode(storedValue: nil), .guided)
    }

    func testSetTunerModeReadsItsStoredValue() {
        XCTAssertEqual(AppSettings.resolvedTunerMode(storedValue: "chromatic"), .chromatic)
    }

    func testUnrecognisedTunerModeFallsBackToGuided() {
        XCTAssertEqual(AppSettings.resolvedTunerMode(storedValue: "spectral"), .guided)
    }

    // MARK: the walking highlight (ADR 0157)

    func testWalkingHighlightDefaultsOn() {
        // ADR 0157 reversed this from off. The seven sites that used to repeat the literal now all
        // read this constant, so pinning it here covers the views too — but note that the check that
        // actually matters is visual, on device (ADR 0157 §2).
        XCTAssertTrue(AppSettings.exerciseAnimatesDefault)
        XCTAssertTrue(AppSettings.resolvedBool(storedValue: nil,
                                               default: AppSettings.exerciseAnimatesDefault))
    }

    func testAnExplicitlyStoredFalseSurvivesTheNewDefault() {
        // ADR 0157 §3: a player who deliberately turned the walk off has a stored `false` and keeps
        // it. Only an absent key moves — nothing may seed the key on launch.
        XCTAssertFalse(AppSettings.resolvedBool(storedValue: false,
                                                default: AppSettings.exerciseAnimatesDefault))
    }

    // MARK: the song player's four display defaults (ADR 0163)

    func testSongPlayerDefaultsMatchTheShippedArrangement() {
        // Two surfaces now open the same screen — the Settings hub and a hold on the player's Loop
        // control — so these four had to stop being literals repeated at three sites each. Pinning
        // the constants is what makes the two doors provably agree: every `@AppStorage` declaration
        // and every accessor reads the value asserted here.
        XCTAssertFalse(AppSettings.transportLoopOnLeftDefault)      // Marker-left / Loop-right
        XCTAssertTrue(AppSettings.waveformMinimapVisibleDefault)
        XCTAssertTrue(AppSettings.waveformMarkerLabelsDefault)
        XCTAssertFalse(AppSettings.zoomFollowsPlayheadDefault)      // pinch holds the focal point
    }

    func testSongPlayerDefaultsSurviveAnUnsetKeyAndYieldToAStoredOne() {
        // Deliberately *not* asserted against the live accessors: those read `UserDefaults.standard`
        // in the test host, so a key set by any earlier run would decide the result (ADR 0146 — a
        // green run that depends on host state isn't a clean one). This pins the rule the accessors
        // apply instead: absent ⇒ the constant, present ⇒ the stored value, both directions.
        for expected in [AppSettings.transportLoopOnLeftDefault,
                         AppSettings.waveformMinimapVisibleDefault,
                         AppSettings.waveformMarkerLabelsDefault,
                         AppSettings.zoomFollowsPlayheadDefault] {
            XCTAssertEqual(AppSettings.resolvedBool(storedValue: nil, default: expected), expected)
            XCTAssertEqual(AppSettings.resolvedBool(storedValue: !expected, default: expected),
                           !expected, "an explicit choice must outrank the default")
        }
    }

    func testReferencePitchDefaultSitsInsideItsRange() {
        // The stepper's default must be a value the stepper can actually reach (A440 in A432–A446).
        XCTAssertTrue(AppSettings.tunerReferenceRange.contains(AppSettings.tunerReferenceDefault))
        XCTAssertEqual(AppSettings.tunerReferenceDefault, 440)
    }
}
