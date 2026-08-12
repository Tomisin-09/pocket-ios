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

    // MARK: - Flow

    @MainActor
    private func openNewExerciseSheet(in app: XCUIApplication) {
        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: Self.uiTimeout), "Practice card missing")
        XCTAssertTrue(scrollIntoView(practiceCard, in: app), "Practice card not reachable by scrolling")
        practiceCard.tap()
        // Wait on the hub itself, not on the row inside it. A tap taken while Home is still settling
        // from `scrollIntoView` can be swallowed, and the failure then reads "Exercises row missing"
        // — a symptom one screen away from the cause (the ADR 0146 lesson). One re-tap, then insist.
        if !app.navigationBars["Practice"].waitForExistence(timeout: Self.uiTimeout) {
            practiceCard.tap()
            XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: Self.uiTimeout),
                          "Practice hub did not open from Home")
        }

        let exercisesRow = app.cells.containing(.staticText, identifier: "Exercises").firstMatch
        XCTAssertTrue(exercisesRow.waitForExistence(timeout: Self.uiTimeout), "Exercises library row missing")
        exercisesRow.tap()

        XCTAssertTrue(app.navigationBars["Exercises"].waitForExistence(timeout: Self.uiTimeout),
                      "Exercises library did not appear")
        let add = app.buttons["New exercise"]
        XCTAssertTrue(add.waitForExistence(timeout: Self.uiTimeout), "New exercise + missing from the library toolbar")
        add.tap()
        XCTAssertTrue(app.navigationBars["New exercise"].waitForExistence(timeout: Self.uiTimeout),
                      "the create sheet did not open on its template picker")
    }

    /// Tap a template row by identifier. The library behind the sheet has its own rows labelled
    /// "Scales" and "Chords", and a label query happily matches those covered ones instead.
    @MainActor
    private func chooseTemplate(_ rawValue: String, in app: XCUIApplication) {
        let row = app.buttons["template.\(rawValue)"]
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "\(rawValue) template row missing")
        XCTAssertTrue(scrollIntoView(row, in: app), "\(rawValue) template row not reachable by scrolling")
        row.tap()
    }
}

/// Mirrors `FretboardGrid.stringCountIdentifier` — the UI test target doesn't link the app's types.
enum FretboardGridIdentifiers {
    static func strings(_ count: Int) -> String { "fretboard.strings.\(count)" }
}
