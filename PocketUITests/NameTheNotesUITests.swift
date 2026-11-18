import XCTest

/// **Name the notes**, driven (ADR 0227, 0234; opened for ADR 0235's build). The rules are unit-tested;
/// what only a driven run shows is the wiring from a touch to the strip. ADR 0235 moves the sheet's neck
/// into a shared editor, and until this nothing opened the sheet, so a broken binding would have shipped.
///
/// The way in is a seeded song (`-seedNamingPiece`) whose *Verse riff* has six unnamed notes: Song library
/// ▸ the song ▸ hold the loop ▸ *Active listening* ▸ *Name the notes*. The seed is put back as it was on each
/// launch, and every other test's launch takes it out, so the shared store is left as the rest expect.
final class NameTheNotesUITests: UITestCase {

    /// The player loads the song's audio before it shows; generous, as the shoot's is.
    private let playerTimeout: TimeInterval = 90

    /// Placing a note fills the chip and moves on; ↶ puts it back (0234 D3, D6).
    @MainActor
    func testPlacingANoteFillsItsChipMovesOnAndUndoes() {
        let app = openNameTheNotes()
        let first = app.descendants(matching: .any)["naming.chip.0"]
        XCTAssertTrue(first.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertEqual(first.label, "Note 1, not named")

        let spot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "G string, fret 2,")).firstMatch
        XCTAssertTrue(spot.waitForExistence(timeout: Self.uiTimeout), "no G string, fret 2 on the neck")
        spot.tap()

        XCTAssertTrue(waitForLabel("Note 1, G2", on: first), "placing didn't fill the chip: \(first.label)")
        let second = app.descendants(matching: .any)["naming.chip.1"]
        XCTAssertTrue(second.isSelected, "placing a note should move on to the next")
        attach(app, named: "naming-placed")

        app.buttons["naming.undo"].tap()
        XCTAssertTrue(waitForLabel("Note 1, not named", on: first), "↶ didn't take the note back: \(first.label)")

        app.navigationBars["Name the notes"].buttons["Cancel"].tap()
    }

    /// A ✕ beside a string names the note muted and moves on, as placing does; *Muted* on By ear does too
    /// (ADR 0262 D2, D3). The chips say it aloud as muted, never "multiplication x".
    @MainActor
    func testACrossAndMutedByEarNameDeadNotes() {
        let app = openNameTheNotes()
        let first = app.descendants(matching: .any)["naming.chip.0"]
        XCTAssertTrue(first.waitForExistence(timeout: Self.uiTimeout))

        let cross = app.buttons["neck.mute.4"]
        XCTAssertTrue(cross.waitForExistence(timeout: Self.uiTimeout), "no ✕ beside the A string")
        cross.tap()
        XCTAssertTrue(waitForLabel("Note 1, A muted", on: first), "the ✕ didn't name the note: \(first.label)")
        let second = app.descendants(matching: .any)["naming.chip.1"]
        XCTAssertTrue(second.isSelected, "a ✕ should move on to the next, as placing does")
        attach(app, named: "naming-muted-on-the-neck")

        app.buttons["By ear"].tap()
        let muted = app.buttons["ear.muted"]
        XCTAssertTrue(reveal(muted, in: app), "no Muted on By ear")
        muted.tap()
        XCTAssertTrue(waitForLabel("Note 2, muted", on: second), "Muted didn't name the note: \(second.label)")
        attach(app, named: "naming-muted-by-ear")

        app.navigationBars["Name the notes"].buttons["Cancel"].tap()
    }

    /// A tap on a chip never snags it; a hold does, and a second hold takes it off (0234 D7). A Button with
    /// a hold would fire both, which is why the chip is a plain shape with two gestures.
    @MainActor
    func testATapNeverSnagsAndAHoldDoes() {
        let app = openNameTheNotes()
        let chip = app.descendants(matching: .any)["naming.chip.2"]
        XCTAssertTrue(chip.waitForExistence(timeout: Self.uiTimeout))

        chip.tap()
        XCTAssertTrue(chip.isSelected, "a tap makes the chip current")
        XCTAssertFalse(chip.label.hasSuffix(", snagged"), "a tap snagged the note: \(chip.label)")

        chip.press(forDuration: 1.0)
        XCTAssertTrue(waitForLabel("Note 3, not named, snagged", on: chip), "a hold didn't snag it: \(chip.label)")
        attach(app, named: "naming-snagged")

        chip.press(forDuration: 1.0)
        XCTAssertTrue(waitForLabel("Note 3, not named", on: chip), "a second hold didn't take it off: \(chip.label)")

        app.navigationBars["Name the notes"].buttons["Cancel"].tap()
    }

    /// *Higher* dims the spots the note can't be, a dimmed spot still takes a tap, and placing takes the arrow
    /// off; an arrow on a note whose note before isn't placed waits on its chip (ADR 0301 D3–D5). The rules
    /// are `PitchDirectionTests`'; this is the wiring from the row to the neck.
    @MainActor
    func testAnArrowDimsTheNeckAndPlacingTakesItOff() {
        let app = openNameTheNotes()
        let first = app.descendants(matching: .any)["naming.chip.0"]
        XCTAssertTrue(first.waitForExistence(timeout: Self.uiTimeout))
        let higher = app.buttons["naming.direction.higher"]
        XCTAssertTrue(higher.waitForExistence(timeout: Self.uiTimeout), "no direction row over the neck")
        XCTAssertFalse(higher.isEnabled, "note 1 has nothing before it")

        // Note 1 on G5, a C.
        neckSpot("G string, fret 5,", in: app).tap()
        let second = app.descendants(matching: .any)["naming.chip.1"]
        XCTAssertTrue(waitForLabel("Note 1, G5", on: first), "placing didn't fill the chip: \(first.label)")
        XCTAssertTrue(second.isSelected, "placing a note should move on to the next")

        higher.tap()
        XCTAssertTrue(higher.isSelected, "Higher didn't light")
        let below = neckSpot("G string, fret 3,", in: app)
        XCTAssertTrue(below.label.hasSuffix(", dimmed"), "G3 is lower than G5 but isn't dimmed: \(below.label)")
        let above = neckSpot("G string, fret 7,", in: app)
        XCTAssertFalse(above.label.contains("dimmed"), "G7 is higher than G5 but is dimmed: \(above.label)")
        XCTAssertFalse(neckSpot("G string, fret 5,", in: app).label.contains("dimmed"),
                       "the note compared with should stay bright")
        attach(app, named: "naming-direction-higher")

        // Dimmed, never locked, and placing wins.
        below.tap()
        XCTAssertTrue(waitForLabel("Note 2, G3", on: second), "a dimmed spot didn't take the tap: \(second.label)")
        second.tap()
        XCTAssertTrue(second.isSelected)
        XCTAssertFalse(higher.isSelected, "placing should have taken the arrow off")

        // Note 4 isn't placed, so an arrow on note 5 waits on its chip and dims nothing.
        let fifth = app.descendants(matching: .any)["naming.chip.4"]
        fifth.tap()
        app.buttons["naming.direction.lower"].tap()
        XCTAssertTrue(waitForLabel("Note 5, not named, heard lower", on: fifth), "no arrow on the chip: \(fifth.label)")
        XCTAssertEqual(app.staticTexts["naming.direction.line"].label, "Nothing is dimmed until note 4 is placed.")
        XCTAssertFalse(neckSpot("G string, fret 3,", in: app).label.contains("dimmed"), "nothing should dim yet")
        attach(app, named: "naming-direction-waiting")

        app.navigationBars["Name the notes"].buttons["Cancel"].tap()
    }

    /// **Another key** (ADR 0305 D3, D5): the stepper moves the key and the line says where to; shifted, the
    /// saved names hide and naming opens a pass that says it isn't kept; *Original key* puts it back.
    @MainActor
    func testAnotherKeyHidesTheNamesAndNamesAPassThatIsntKept() {
        let app = openActiveListening()
        let line = app.staticTexts["listening.key.line"]
        XCTAssertTrue(reveal(line, in: app), "no key line under the steppers")
        XCTAssertEqual(line.label, "G minor, as recorded")

        let raise = app.buttons["Up a semitone"]
        for _ in 0..<3 { raise.tap() }
        XCTAssertTrue(waitForLabel("B♭ minor · 3 up", on: line), "the line didn't follow the key: \(line.label)")
        attach(app, named: "another-key-shifted")

        let hidden = app.descendants(matching: .any)["count.saved.hidden"]
        XCTAssertTrue(reveal(hidden, in: app), "the saved names aren't hidden while shifted")
        let name = app.buttons["count.saved.name"]
        XCTAssertTrue(reveal(name, in: app))
        XCTAssertEqual(name.label, "Name the notes in B♭ minor")
        name.tap()
        XCTAssertTrue(app.navigationBars["Name the notes"].waitForExistence(timeout: Self.uiTimeout))
        XCTAssertTrue(app.staticTexts["naming.shifted.line"].waitForExistence(timeout: Self.uiTimeout),
                      "naming at a shift should say its names aren't kept")
        app.navigationBars["Name the notes"].buttons["Cancel"].tap()

        // Back up the Form: the key's row is above the saved piece, and `reveal` only drags one way. The drag
        // runs down the Form's left margin, outside every card: down the middle it starts on Count the notes'
        // tap pad, which takes it as a tap, and the Form never moves.
        let original = app.buttons["listening.key.original"]
        for _ in 0..<8 where !inReach(original, in: app) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.3))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.8)),
                       withVelocity: .default, thenHoldForDuration: 0.3)
        }
        XCTAssertTrue(inReach(original, in: app), "no Original key while shifted")
        original.tap()
        XCTAssertTrue(waitForLabel("G minor, as recorded", on: line), "Original key didn't go back: \(line.label)")
        XCTAssertFalse(app.descendants(matching: .any)["count.saved.hidden"].exists, "the names should be back")
    }

    // MARK: - The way in

    /// A spot on the neck by the start of its label: *"G string, fret 5,"*.
    @MainActor
    private func neckSpot(_ start: String, in app: XCUIApplication) -> XCUIElement {
        let spot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", start)).firstMatch
        XCTAssertTrue(spot.waitForExistence(timeout: Self.uiTimeout), "no \(start) on the neck")
        return spot
    }

    @MainActor
    private func openNameTheNotes(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = openActiveListening(file: file, line: line)
        let name = app.buttons["count.saved.name"]
        XCTAssertTrue(reveal(name, in: app), "no saved piece on the loop — did the seed run?", file: file, line: line)
        name.tap()
        XCTAssertTrue(app.navigationBars["Name the notes"].waitForExistence(timeout: Self.uiTimeout),
                      "Name the notes didn't open", file: file, line: line)
        return app
    }

    @MainActor
    private func openActiveListening(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp(extraArguments: [UITestHooks.namingPieceArgument], file: file, line: line)

        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home",
                      file: file, line: line)
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open",
                      file: file, line: line)

        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library",
                      file: file, line: line)
        XCTAssertTrue(scrollIntoView(song, in: app), "the seeded song isn't reachable", file: file, line: line)
        song.tap()
        XCTAssertTrue(app.buttons["Back to library"].waitForExistence(timeout: playerTimeout),
                      "the song player never opened", file: file, line: line)

        let loop = app.buttons["Play Verse riff"]
        XCTAssertTrue(loop.waitForExistence(timeout: Self.uiTimeout), "no Verse riff row", file: file, line: line)
        loop.press(forDuration: 1.0)
        XCTAssertTrue(app.navigationBars["Edit loop"].waitForExistence(timeout: Self.uiTimeout),
                      "holding the loop didn't open Edit loop", file: file, line: line)

        let train = app.buttons["Active listening on this loop"]
        XCTAssertTrue(reveal(train, in: app), "no Active listening in Edit loop", file: file, line: line)
        train.tap()
        XCTAssertTrue(app.navigationBars["Active listening"].waitForExistence(timeout: Self.uiTimeout),
                      "Active listening didn't open", file: file, line: line)
        return app
    }

    /// Drag up until `element` is drawn and in reach. A Form draws its rows only as they come near the
    /// screen, and a sheet opens at half height, where `swipeUp()` lands on the sheet's top edge rather
    /// than its rows: so the drag starts low on the screen, inside the sheet. The Count the notes pad takes
    /// a drag as its own, so the start alternates between two heights further apart than the pad is tall.
    /// Each drag holds at its end, so the Form stops where it was left instead of coasting on.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        _ = element.waitForExistence(timeout: 2)
        for attempt in 0..<12 {
            if inReach(element, in: app) { return true }
            let start = attempt.isMultiple(of: 2) ? 0.85 : 0.55
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start - 0.4)),
                       withVelocity: .default, thenHoldForDuration: 0.3)
        }
        return inReach(element, in: app)
    }

    /// Whole on screen and clear of the home indicator. `isHittable` alone isn't enough: iOS 18 calls a
    /// button hittable with 11 points of it showing at the foot of the screen, and the tap there goes to
    /// the system, so *Name the notes* never opened on CI while it did on iOS 26.
    @MainActor
    private func inReach(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let window = app.windows.firstMatch.frame
        return element.frame.minY >= window.minY && element.frame.maxY <= window.maxY - homeIndicatorClearance
    }

    /// The strip at the foot of the screen a touch can't reach an app through.
    private let homeIndicatorClearance: CGFloat = 40

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
