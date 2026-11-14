import XCTest

/// **A swap opens on the chord it replaces** (ADR 0297).
///
/// Which shape and root a chord reads back as is unit-tested (`ChordPickerCurrentTests`). What only a UI
/// test can see is that the editor hands the chord over: the picker opens with the root row on its root
/// and its shape marked, a chip under a chosen root inserts the chord it shows, and the two moves a swap
/// is for — another shape at the same root, the same shape at another root — each land in the row.
final class ChordSwapUITests: UITestCase {

    @MainActor
    func testASwapOpensOnItsRootAndBothMovesLand() throws {
        let app = launchApp()
        openNewExerciseSheet(in: app)
        chooseTemplate("chords", in: app)

        // Add opens on Any, where a movable chip is a shape over a root menu — the picker as it was.
        let addChord = app.buttons["Add chord"].firstMatch
        XCTAssertTrue(addChord.waitForExistence(timeout: Self.uiTimeout), "Add chord missing from the editor")
        XCTAssertTrue(scrollIntoView(addChord, in: app), "Add chord not reachable by scrolling")
        addChord.tap()
        XCTAssertTrue(app.navigationBars["Add a chord"].waitForExistence(timeout: Self.uiTimeout),
                      "the chord picker did not open")
        XCTAssertTrue(app.buttons["chordPicker.root.any"].isSelected, "Add should open on Any")
        let minorShape = app.buttons["Minor E-shape barre, choose a root"].firstMatch
        XCTAssertTrue(minorShape.waitForExistence(timeout: Self.uiTimeout), "E-shape minor chip missing")
        minorShape.tap()
        let rootA = app.buttons["A"].firstMatch
        XCTAssertTrue(rootA.waitForExistence(timeout: Self.uiTimeout), "the root menu did not open")
        rootA.tap()

        // The swap opens on A, with the E-shape minor marked.
        swap("Am", in: app)
        XCTAssertTrue(app.buttons["chordPicker.root.9"].isSelected, "the swap should open on the chord's root")
        let current = app.buttons["Insert Am, E-shape barre"]
        XCTAssertTrue(current.waitForExistence(timeout: Self.uiTimeout), "the placed Am chip is missing")
        XCTAssertEqual(current.value as? String, "Current shape", "the chord being swapped isn't marked")
        attachScreenshot(of: app, named: "swap-opens-on-the-chord")

        // Same root, another shape: one tap.
        tapChip("Insert Am7, E-shape barre", in: app)
        XCTAssertTrue(app.buttons["Swap chord Am7"].waitForExistence(timeout: Self.uiTimeout),
                      "another shape at the same root did not land")

        // Same shape, another root: the root, then the marked chip.
        swap("Am7", in: app)
        let rootG = app.buttons["chordPicker.root.7"]
        XCTAssertTrue(rootG.waitForExistence(timeout: Self.uiTimeout), "the root row is missing")
        rootG.tap()
        let slid = app.buttons["Insert Gm7, E-shape barre"]
        XCTAssertTrue(slid.waitForExistence(timeout: Self.uiTimeout), "the shape did not redraw at G")
        XCTAssertEqual(slid.value as? String, "Current shape", "the mark didn't follow the shape to G")
        attachScreenshot(of: app, named: "swap-same-shape-another-root")
        tapChip("Insert Gm7, E-shape barre", in: app)
        XCTAssertTrue(app.buttons["Swap chord Gm7"].waitForExistence(timeout: Self.uiTimeout),
                      "the same shape at another root did not land")

        // A chord far down the grid: open C sits under twelve movable shapes and eighteen triads. The
        // swap has to open scrolled to it, or the mark is there and nobody sees it.
        swap("Gm7", in: app)
        app.buttons["chordPicker.root.0"].tap()
        let openC = app.buttons["Insert C"]
        XCTAssertTrue(swipeUntilHittable(openC, in: app), "open C not reachable under the root C")
        tapChip("Insert C", in: app)
        swap("C", in: app)
        let markedC = app.buttons["Insert C"]
        XCTAssertTrue(markedC.waitForExistence(timeout: Self.uiTimeout),
                      "the open C chip isn't in the tree — the sheet did not scroll to it")
        XCTAssertTrue(markedC.isHittable, "the open C chip is off screen when the swap opens")
        XCTAssertEqual(markedC.value as? String, "Current chord")
        attachScreenshot(of: app, named: "swap-opens-scrolled-to-an-open-shape")
    }

    @MainActor
    private func swap(_ name: String, in app: XCUIApplication) {
        let row = app.buttons["Swap chord \(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "no \(name) row to swap")
        XCTAssertTrue(scrollIntoView(row, in: app), "the \(name) row not reachable by scrolling")
        row.tap()
        XCTAssertTrue(app.navigationBars["Swap chord"].waitForExistence(timeout: Self.uiTimeout),
                      "the picker did not open for a swap")
    }

    @MainActor
    private func tapChip(_ label: String, in app: XCUIApplication) {
        let chip = app.buttons[label]
        XCTAssertTrue(chip.waitForExistence(timeout: Self.uiTimeout), "\(label) missing from the picker")
        chip.tap()
        XCTAssertTrue(waitForDisappearance(of: app.navigationBars["Swap chord"]),
                      "the picker did not close on insert")
    }

    /// Swipe the picker up until a chip is on screen. Not `scrollIntoView`, which gives up on an element
    /// that doesn't exist yet: a chip in a lazy grid below the fold isn't in the tree until it nears it.
    @MainActor
    private func swipeUntilHittable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// Kept always: a green run can't see a clipped chip or a crowded row, and this is a changed screen.
    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
