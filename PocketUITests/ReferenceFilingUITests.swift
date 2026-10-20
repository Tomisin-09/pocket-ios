import XCTest

/// **Filing a reference** (ADR 0264 D5): a link kept for later starts a drill, and is then attached to a
/// second place. The rules are `ReferenceFilingTests` and `ReferenceDestinationPickerTests`; what only a
/// driven run shows is the wiring: the start button runs New exercise and the drill takes the link, and
/// the picker opens, finds a place, attaches and closes.
///
/// The simulator keeps its store between runs, so the link is made unique to this run and found by that.
/// It is deleted at the end; the drill it started stays, like every drill a UI test makes.
final class ReferenceFilingUITests: UITestCase {

    @MainActor
    func testAKeptLinkStartsADrillThenIsAlsoAttachedToAnother() {
        let app = launchApp()
        let run = String(UUID().uuidString.prefix(6)).lowercased()
        let host = "lesson\(run).example.com"
        let drill = "Filed drill \(run)"

        openReferences(in: app)
        addLink("https://\(host)/caged", in: app)

        // Kept for later: it opens on the start button, as drawn.
        let row = element(labelStartingWith: host, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "the link kept for later isn't in the library")
        let start = app.buttons["Start an exercise from this"]
        XCTAssertTrue(tap(row, until: start, in: app), "the source didn't open on Start an exercise from this")
        XCTAssertTrue(app.buttons["Attach to…"].exists, "a source not filed offers Attach to…")
        screenshot(app, "source-not-filed")

        // New exercise, as in Practice; the drill it makes opens.
        XCTAssertTrue(tap(start, until: app.navigationBars["New exercise"], in: app), "New exercise didn't open")
        createDrill(named: drill, in: app)

        // Back on the source: filed on the new drill, and the buttons say so.
        let onDrill = element(labelStartingWith: drill, in: app)
        XCTAssertTrue(onDrill.waitForExistence(timeout: Self.uiTimeout), "the new drill didn't take the link")
        let also = app.buttons["Also attach to…"]
        XCTAssertTrue(also.exists, "a filed source offers Also attach to…")
        XCTAssertTrue(app.buttons["Start another exercise from this"].exists)
        screenshot(app, "source-filed")

        // Also attach to a preset drill, found by search.
        XCTAssertTrue(tap(also, until: app.navigationBars["Also attach to"], in: app), "the picker didn't open")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: Self.uiTimeout), "the picker has no search")
        screenshot(app, "picker")
        search.tap()
        search.typeText("Alternate")
        let place = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Alternate Picking")).firstMatch
        XCTAssertTrue(place.waitForExistence(timeout: Self.uiTimeout), "the search didn't find Alternate Picking")
        screenshot(app, "picker-search")
        place.tap()
        XCTAssertTrue(waitForDisappearance(of: app.navigationBars["Also attach to"]), "the picker didn't close")

        let delete = app.buttons["Delete from both places…"]
        XCTAssertTrue(delete.waitForExistence(timeout: Self.uiTimeout),
                      "the source should be in two places now, the new drill and Alternate Picking")
        XCTAssertTrue(element(labelStartingWith: "Alternate Picking", in: app).exists)

        // Tidy up: the link goes from both, and the library no longer lists it.
        deleteSource(with: delete, listedAs: row, in: app)
    }

    /// **Without the plan** (D6): the start button wears the lock and leads to the wall, and the picker
    /// offers songs and loops only, saying why. The rules are unit-tested; this is the screen reading
    /// the player's real standing from `PlanStore`.
    @MainActor
    func testWithoutThePlanThePickerOffersSongsAndLoopsAndStartingShowsTheWall() {
        let app = launchApp(extraArguments: [UITestHooks.planArgument, UITestHooks.planFree])
        let host = "free\(String(UUID().uuidString.prefix(6)).lowercased()).example.com"

        openReferences(in: app)
        addLink("https://\(host)/lesson", in: app)
        let row = element(labelStartingWith: host, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "the link kept for later isn't in the library")
        let start = app.buttons["Start an exercise from this"]
        XCTAssertTrue(tap(row, until: start, in: app), "the source didn't open")
        XCTAssertEqual(start.value as? String, "Needs the plan", "the start button drew no lock without the plan")
        screenshot(app, "source-free")

        XCTAssertTrue(tap(app.buttons["Attach to…"], until: app.navigationBars["Attach to"], in: app),
                      "the picker didn't open")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: Self.uiTimeout), "the picker has no search")
        XCTAssertEqual(search.placeholderValue, "Search songs and loops", "the search offered what it can't find")
        let footer = app.staticTexts["Exercises and routines come with the plan."]
        if !footer.waitForExistence(timeout: 2) { app.swipeUp() }
        XCTAssertTrue(footer.waitForExistence(timeout: Self.uiTimeout),
                      "the picker didn't say exercises and routines come with the plan")
        screenshot(app, "picker-free")
        // The drill the plan's test attaches to isn't offered at all. Everything lists exercises first, so
        // it would be at the top. Not searched for: a search swaps the sheet's Cancel for its own control.
        let everything = app.buttons["Show all songs and loops"]
        if everything.exists {
            XCTAssertTrue(tap(everything, until: app.navigationBars["Songs and loops"], in: app),
                          "Show all songs and loops didn't open")
        }
        let drill = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Alternate Picking")).firstMatch
        XCTAssertFalse(drill.waitForExistence(timeout: 2), "a free player was offered a drill")
        if app.navigationBars["Songs and loops"].exists {
            app.navigationBars["Songs and loops"].buttons.element(boundBy: 0).tap()
        }
        let cancel = app.navigationBars["Attach to"].buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: Self.uiTimeout), "the picker has no Cancel")
        cancel.tap()
        XCTAssertTrue(waitForDisappearance(of: search), "Cancel didn't close the picker")

        let wall = app.staticTexts[UITestHooks.planWallHeadline]
        XCTAssertTrue(tap(start, until: wall, in: app), "starting an exercise without the plan didn't show the wall")
        app.buttons["Not now"].tap()
        XCTAssertTrue(waitForDisappearance(of: wall), "Not now didn't close the wall")

        deleteSource(with: app.buttons["Delete"].firstMatch, listedAs: row, in: app)
    }

    // MARK: - Steps

    /// From New exercise's template picker: a Basic drill named `name`, created, its run screen opened
    /// (open on create), then back to where it was started.
    @MainActor
    private func createDrill(named name: String, in app: XCUIApplication) {
        chooseTemplate("basic", in: app)
        let field = app.textFields["e.g. Spider"]
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout), "the configure step has no name field")
        field.tap()
        field.typeText(name)
        app.navigationBars.buttons["Create"].tap()
        XCTAssertTrue(app.buttons["Exercise details"].waitForExistence(timeout: Self.uiTimeout),
                      "the new drill's run screen didn't open")
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    /// Delete the source for good, through its dialog, and see it leave the library. The dialog's
    /// button is the *Delete* that isn't where `button` is: not filed, the screen's own reads *Delete*
    /// too.
    @MainActor
    private func deleteSource(with button: XCUIElement, listedAs row: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(scrollIntoView(button, in: app), "Delete isn't reachable")
        let pressed = button.frame
        let deletes = app.buttons.matching(NSPredicate(format: "label == 'Delete'"))
        let before = deletes.count
        button.tap()
        // A format predicate, not a block: a block would read the query off the main actor, which CI's
        // Swift 6 refuses.
        let asked = expectation(for: NSPredicate(format: "count > %d", before), evaluatedWith: deletes)
        XCTAssertEqual(XCTWaiter().wait(for: [asked], timeout: Self.uiTimeout), .completed, "Delete didn't ask first")
        let confirm = deletes.allElementsBoundByIndex.first { $0.frame != pressed }
        XCTAssertNotNil(confirm, "the dialog's Delete can't be told from the screen's")
        confirm?.tap()
        XCTAssertTrue(app.navigationBars["References"].waitForExistence(timeout: Self.uiTimeout),
                      "deleting didn't return to the library")
        XCTAssertTrue(waitForDisappearance(of: row), "the deleted source is still listed")
    }

    /// Home ▸ Toolkit ▸ References. Each tap is retried, as `MyTabsUITests` retries them: a tap as the
    /// Toolkit slid in has opened nothing before.
    @MainActor
    private func openReferences(in app: XCUIApplication) {
        let toolkit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Toolkit,")).firstMatch
        XCTAssertTrue(toolkit.waitForExistence(timeout: Self.uiTimeout), "no Toolkit on Home")
        XCTAssertTrue(tap(toolkit, until: app.navigationBars["Toolkit"], in: app), "the Toolkit didn't open")
        let references = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "References,")).firstMatch
        XCTAssertTrue(references.waitForExistence(timeout: Self.uiTimeout), "no References row")
        XCTAssertTrue(tap(references, until: app.navigationBars["References"], in: app), "References didn't open")
    }

    /// ＋ ▸ Add a link, typed, saved with no name: the row then reads as its host, which is this run's own.
    ///
    /// ＋ is a toolbar `Menu`, tapped by coordinate: on CI's iOS 18 such a menu is found but never
    /// reported hittable. The link field is a vertical `TextField`, found by identifier across every
    /// element type, since iOS 18 calls it a text view and iOS 26 a text field.
    @MainActor
    private func addLink(_ url: String, in app: XCUIApplication) {
        let add = app.navigationBars["References"].buttons["Add a reference"]
        XCTAssertTrue(add.waitForExistence(timeout: Self.uiTimeout), "no ＋ on References")
        add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let addLink = app.buttons["Add a link"]
        XCTAssertTrue(addLink.waitForExistence(timeout: Self.uiTimeout), "＋ didn't offer Add a link")
        addLink.tap()

        let field = app.descendants(matching: .any)[UITestHooks.referenceLinkField]
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout), "the link editor didn't open")
        field.tap()
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: Self.uiTimeout), .completed,
                       "the link field never took the keyboard")
        field.typeText(url)
        let save = app.navigationBars.buttons["Save"]
        XCTAssertTrue(save.isEnabled, "Save is off with a link typed")
        save.tap()
        XCTAssertTrue(waitForDisappearance(of: field), "the editor didn't close on Save")
    }

    @MainActor
    private func element(labelStartingWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "references-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
