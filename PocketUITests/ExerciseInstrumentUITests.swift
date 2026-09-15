import XCTest

/// The **instrument axis survives the create flow** (ADR 0116 S6).
///
/// The Guitar/Bass control lives on step one of `NewExerciseSheet` and the neck is drawn on step
/// two, so the only thing that carries the choice across is the push itself. Every layer below it —
/// `ScaleRun.expanded(instrument:)`, the seeded runs, `FretboardDrill.stringCount` — is already unit
/// tested and correct in isolation, which is precisely why the break was invisible: the value simply
/// never arrived. Nothing but a UI test can see that, so this is the guard.
///
/// Asserts on `FretboardGrid.stringCountIdentifier` rather than the string-name captions: "B" is a
/// guitar string *and* a root-picker letter, and a query that can't tell them apart would pass on a
/// broken build.
final class ExerciseInstrumentUITests: UITestCase {

    /// Bass chosen on the picker step must reach the configure step's board — four strings, not six.
    @MainActor
    func testBassChosenOnPickerDrawsFourStringNeck() throws {
        let app = launchApp()
        openNewExerciseSheet(in: app)

        let bass = app.buttons["Bass"].firstMatch
        XCTAssertTrue(bass.waitForExistence(timeout: Self.uiTimeout),
                      "Guitar/Bass control missing from the New exercise picker (ADR 0116 S6)")
        bass.tap()

        chooseTemplate("scales", in: app)

        let bassNeck = app.otherElements[FretboardGridIdentifiers.strings(4)]
        let guitarNeck = app.otherElements[FretboardGridIdentifiers.strings(6)]
        XCTAssertTrue(bassNeck.waitForExistence(timeout: Self.uiTimeout),
                      """
                      the configure step drew no four-string neck after Bass was chosen. \
                      If a six-string board is on screen, the instrument never reached \
                      ConfigureExerciseForm — check what NewExerciseSheet hands the push, not the \
                      generators (they are unit-tested).
                      """)
        XCTAssertFalse(guitarNeck.exists, "a guitar neck is on screen for a bass drill")

        // Kept always: the identifier proves the string count, but a defect in *this* area is the kind
        // that reads correct in code and wrong on screen, so the board is worth a look after a change.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "bass-scale-configure-step"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The default still holds: an untouched picker (profile default = guitar) draws six strings, so
    /// the fix above can't have simply flipped the axis.
    @MainActor
    func testUntouchedPickerDrawsSixStringNeck() throws {
        let app = launchApp()
        openNewExerciseSheet(in: app)
        chooseTemplate("scales", in: app)

        let guitarNeck = app.otherElements[FretboardGridIdentifiers.strings(6)]
        XCTAssertTrue(guitarNeck.waitForExistence(timeout: Self.uiTimeout),
                      "the configure step did not draw a guitar neck for the default instrument")
    }

    /// A bass Chords drill draws **four-string** chord boxes and is offered the bass vocabulary
    /// (ADR 0164). The picker's own sections are the proof that the guitar catalog stood down: a
    /// six-string diagram anywhere in this flow means a guitar shape was offered for a bass drill.
    @MainActor
    func testBassChordsDrillUsesTheBassNeckAndVocabulary() throws {
        let app = launchApp()
        openNewExerciseSheet(in: app)

        let bass = app.buttons["Bass"].firstMatch
        XCTAssertTrue(bass.waitForExistence(timeout: Self.uiTimeout), "Guitar/Bass control missing")
        bass.tap()

        // The strum-lane templates stand down on bass; Chords does not.
        XCTAssertFalse(app.buttons["template.strumChords"].exists,
                       "Chords & Strum is offered on bass (ADR 0164 D4)")
        XCTAssertFalse(app.buttons["template.strumming"].exists, "Strumming is offered on bass")
        chooseTemplate("chords", in: app)

        let addChord = app.buttons["Add chord"].firstMatch
        XCTAssertTrue(addChord.waitForExistence(timeout: Self.uiTimeout),
                      "Add chord missing from the editor")
        addChord.tap()

        XCTAssertTrue(app.navigationBars["Add a chord"].waitForExistence(timeout: Self.uiTimeout),
                      "the chord picker did not open")
        let bassChip = app.buttons["Power (root + 5th), choose a root"].firstMatch
        XCTAssertTrue(bassChip.waitForExistence(timeout: Self.uiTimeout),
                      "no bass shapes offered for a bass chords drill")
        XCTAssertFalse(app.otherElements["chord.strings.6"].exists,
                       "a six-string chord box is on screen for a bass drill")

        bassChip.tap()
        let root = app.buttons["C"].firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: Self.uiTimeout), "the root menu did not open")
        root.tap()

        XCTAssertTrue(app.otherElements["chord.strings.4"].waitForExistence(timeout: Self.uiTimeout),
                      "the inserted bass chord did not draw a four-string box")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "bass-chords-configure-step"
        shot.lifetime = .keepAlways
        add(shot)
    }
}

/// Mirrors `FretboardGrid.stringCountIdentifier` — the UI test target doesn't link the app's types.
enum FretboardGridIdentifiers {
    static func strings(_ count: Int) -> String { "fretboard.strings.\(count)" }
}
