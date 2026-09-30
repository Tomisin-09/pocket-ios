import XCTest

/// **Name the notes**, driven (ADR 0227, 0234; opened for ADR 0235's build). The rules are unit-tested;
/// what only a driven run shows is the wiring from a touch to the strip. ADR 0235 moves the sheet's neck
/// into a shared editor, and until this nothing opened the sheet, so a broken binding would have shipped.
///
/// The way in is a seeded song (`-seedNamingPiece`) whose *Verse riff* has six unnamed notes: Song library
/// ▸ the song ▸ hold the loop ▸ *Train your ear* ▸ *Name the notes*. The seed is put back as it was on each
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

    // MARK: - The way in

    @MainActor
    private func openNameTheNotes(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
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

        let train = app.buttons["Train your ear on this loop"]
        XCTAssertTrue(reveal(train, in: app), "no Train your ear in Edit loop", file: file, line: line)
        train.tap()
        XCTAssertTrue(app.navigationBars["Train your ear"].waitForExistence(timeout: Self.uiTimeout),
                      "Train your ear didn't open", file: file, line: line)

        let name = app.buttons["count.saved.name"]
        XCTAssertTrue(reveal(name, in: app), "no saved piece on the loop — did the seed run?", file: file, line: line)
        name.tap()
        XCTAssertTrue(app.navigationBars["Name the notes"].waitForExistence(timeout: Self.uiTimeout),
                      "Name the notes didn't open", file: file, line: line)
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
