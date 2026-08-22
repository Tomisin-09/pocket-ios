import XCTest

/// The **Routines** library's wiring (ADR 0178), and the first UI coverage this screen has ever had.
///
/// `PocketUITests` had no routine file at all — every other library screen has one — so ADR 0127's
/// authoring gestures and the detail screen's Cancel/Save contract were device-verified only
/// (`docs/backlog.md`, Routines item 8). What is covered here is chosen for what a unit test
/// structurally cannot reach: the *wiring* between a control and the state it is supposed to change.
/// The ordering and matching themselves are pure and pinned in `PracticeLibrarySortTests`; nothing
/// here re-asserts them.
///
/// **The sort pickers are deliberately not driven.** They live inside the toolbar `Menu`
/// (`LibraryOptionsMenu`), and a toolbar `Menu`'s items do not resolve through `app.buttons[…]` on
/// CI's macOS-15 / Xcode 16 toolchain — deterministically, and through `-retry-tests-on-failure`.
/// A context menu from `press(forDuration:)` resolves fine on the same runner (`RowUndoUITests`
/// proves it), so the two presentations are not interchangeable. A test that opened that menu would
/// pass on every dev machine and fail every CI run, which is worse than no test. The sort *keys* are
/// unit-tested instead, and the menu route stays a device check until that toolchain gap closes.
///
/// **Every assertion is a delta, never an absolute.** The simulator keeps the app's store between
/// runs, so "the list shows one routine" is a claim about the last run as much as this one. Each
/// test asserts that something *changed* — a row left, a row came back, prose appeared — which holds
/// on a clean install and a dirty one alike.
final class RoutineLibraryUITests: UITestCase {

    /// The seeded starter routine (`RoutinePresets`), present on any install that has not deleted it.
    private static let seededRoutine = "Morning Routine"

    // MARK: - Search (ADR 0178)

    /// Typing narrows the list, and clearing puts it back.
    ///
    /// The query is deliberately a string nothing can match, rather than a prefix of some other
    /// routine's name: the point of the assertion is that the *filter* runs at all, and a query that
    /// happens to match a second routine on a dirty simulator would leave a row on screen and read
    /// as a broken filter.
    @MainActor
    func testSearchNarrowsTheListAndClearingRestoresIt() throws {
        let app = launchApp()
        try openRoutinesLibrary(in: app)

        let routine = app.cells.containing(.staticText, identifier: Self.seededRoutine).firstMatch
        XCTAssertTrue(routine.waitForExistence(timeout: Self.uiTimeout),
                      "no seeded routine to search for")

        let field = try searchField(in: app)
        field.tap()
        field.typeText("zzzqqq")

        XCTAssertTrue(waitForDisappearance(of: routine),
                      "the search query did not narrow the list")
        XCTAssertTrue(app.staticTexts["No routines match “zzzqqq”."].waitForExistence(timeout: Self.uiTimeout),
                      "a search with no hits showed no message saying so")

        // Clearing is its own path: the filter has to run again on an empty query, and an
        // `isEmpty` guard that returned the wrong answer would strand the list empty.
        app.buttons["Clear text"].firstMatch.tap()
        XCTAssertTrue(routine.waitForExistence(timeout: Self.uiTimeout),
                      "clearing the search did not restore the list")
    }

    // MARK: - Description (ADR 0177), and searching by it (ADR 0178)

    /// The detail screen's **Cancel discards, Save keeps** contract applied to the description, then
    /// the library finding the routine by a word that appears only in that description.
    ///
    /// One test rather than three, because the three are one story and the third needs the first two
    /// to have happened: prose that Cancel failed to discard would make the search assertion pass for
    /// the wrong reason.
    ///
    /// The text is **unique per run** and **cleared again at the end**. The store survives between
    /// runs, so a fixed string would be found by the next run before this run wrote it — the search
    /// would pass against last run's leftovers — and a description left behind would sit in every
    /// subsequent run's fixtures.
    @MainActor
    func testADescriptionIsDiscardedByCancelKeptBySaveAndFoundBySearch() throws {
        let app = launchApp()
        try openRoutinesLibrary(in: app)

        let token = "desc\(Int.random(in: 100_000...999_999))"
        try openSeededRoutine(in: app)

        // Cancel discards — asserted by **reopening the editor and reading the field**, not by
        // looking for the text on the read-only screen. The typed text was a field value and never
        // a `staticText`, so "it isn't there" would have been true before Cancel as well: the
        // assertion would have passed without the feature working at all.
        try setDescription(token, in: app)
        dismissKeyboard(in: app)
        tapWhenHittable(app.navigationBars.buttons["Cancel"], called: "Cancel")

        tapWhenHittable(app.navigationBars.buttons["Edit"], called: "Edit")
        let reopened = try descriptionField(in: app)
        XCTAssertFalse((reopened.value as? String ?? "").contains(token),
                       "Cancel kept the description — the sandbox was not rebuilt")

        // Save keeps, and the read-only section draws it.
        clear(reopened)
        reopened.tap()
        reopened.typeText(token)
        save(in: app)

        // The list scrolls to keep the focused field above the keyboard, and a `List` row that
        // scrolled out of view is **absent from the accessibility tree**, not merely off-screen —
        // so an assertion made from wherever the keyboard left us reads a missing row as a missing
        // feature. Go back to the top first: Description is the read-only screen's first section.
        scrollToTop(in: app)
        XCTAssertTrue(app.staticTexts[token].waitForExistence(timeout: Self.uiTimeout),
                      "Save did not keep the description, or the read-only section did not draw it")

        // Back to the library, and find the routine by a word that is in no routine's *name*.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let field = try searchField(in: app)
        field.tap()
        field.typeText(token)
        let routine = app.cells.containing(.staticText, identifier: Self.seededRoutine).firstMatch
        XCTAssertTrue(routine.waitForExistence(timeout: Self.uiTimeout),
                      "search matched names only — a description is where the searchable words live")

        // Put the fixture back, so the next run starts where this one did.
        app.buttons["Clear text"].firstMatch.tap()
        try openSeededRoutine(in: app)
        try setDescription("", in: app)
        save(in: app)
    }

    // MARK: - Taps that survive a slow runner

    /// Tap `element` once it is actually hittable.
    ///
    /// `waitForExistence` returns when an element joins the tree, not when it has settled, and a tap
    /// synthesised into a still-animating push is **swallowed** — the run then fails at the next
    /// step, describing something two screens away. This cost one full run here before it was
    /// applied (and `docs/backlog.md` records the same trap costing the shoot harness a CI round).
    @MainActor
    private func tapWhenHittable(_ element: XCUIElement, called name: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"),
                                   evaluatedWith: element)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: Self.uiTimeout), .completed,
                       "\(name) never became tappable", file: file, line: line)
        element.tap()
    }

    /// Commit the editor. Reached through `navigationBars` rather than `app.buttons[…]`: while the
    /// keyboard is up the screen carries a second toolbar, and `firstMatch` over the whole app is a
    /// promise about tree order that nothing enforces.
    @MainActor
    private func save(in app: XCUIApplication) {
        dismissKeyboard(in: app)
        tapWhenHittable(app.navigationBars.buttons["Save"], called: "Save")
    }

    /// Put the keyboard away via the app's own accessory button, so the nav bar is unobstructed and
    /// the field has resigned first responder before anything is committed.
    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["Dismiss keyboard"]
        guard done.exists, done.isHittable else { return }
        done.tap()
    }

    /// Swipe back to the top of the current list. Stops as soon as the content stops moving, for the
    /// same reason `scrollIntoView` does: a fixed swipe budget is a guess about a layout.
    @MainActor
    private func scrollToTop(in app: XCUIApplication, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes {
            let before = app.cells.firstMatch.frame
            app.swipeDown()
            if app.cells.firstMatch.frame == before { return }
        }
    }

    // MARK: - Reach

    /// Home → Practice → Routines.
    @MainActor
    private func openRoutinesLibrary(in app: XCUIApplication) throws {
        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: Self.uiTimeout), "Practice card missing")
        XCTAssertTrue(scrollIntoView(practiceCard, in: app), "Practice card not reachable by scrolling")
        tapWhenHittable(practiceCard, called: "the Practice card")

        let routinesRow = app.cells.containing(.staticText, identifier: "Routines").firstMatch
        XCTAssertTrue(routinesRow.waitForExistence(timeout: Self.uiTimeout), "Routines library row missing")
        tapWhenHittable(routinesRow, called: "the Routines library row")
        XCTAssertTrue(app.navigationBars["Routines"].waitForExistence(timeout: Self.uiTimeout),
                      "the Routines library never appeared")
    }

    /// The library's search field. Named through a helper because an empty `.searchable` field is
    /// reachable as a `searchField` but carries no value to match on, so `firstMatch` is the only
    /// dependable query — and a bare `firstMatch` at four call sites is four places to be wrong.
    @MainActor
    private func searchField(in app: XCUIApplication) throws -> XCUIElement {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout),
                      "the Routines library has no search field")
        return field
    }

    /// Open the seeded routine's detail screen from the library. The row is two buttons — ▶ and the
    /// body — so it taps the **name**, not the cell, which would otherwise hit whichever half the
    /// frame's centre lands in.
    @MainActor
    private func openSeededRoutine(in app: XCUIApplication) throws {
        let name = app.staticTexts[Self.seededRoutine].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: Self.uiTimeout), "no seeded routine to open")
        XCTAssertTrue(scrollIntoView(name, in: app), "the seeded routine is not reachable by scrolling")
        name.tap()
        XCTAssertTrue(app.buttons["Edit"].firstMatch.waitForExistence(timeout: Self.uiTimeout),
                      "the routine detail screen never appeared")
    }

    /// Enter edit mode and set the Description to **exactly** `text`, clearing whatever was there.
    ///
    /// The clear is not tidiness. The simulator keeps the app's store between runs, and a run that
    /// fails before its restore step leaves its text behind — so `tap()` + `typeText` *appends*, and
    /// the field ends up holding one token per historical run. That is precisely how this test first
    /// failed: the description read `desc264458desc473398desc695656…`, the feature having worked
    /// perfectly every time, and the exact-label assertion could never have matched. Setting the
    /// field rather than adding to it makes each run start from the same place on any machine.
    @MainActor
    private func setDescription(_ text: String, in app: XCUIApplication) throws {
        tapWhenHittable(app.navigationBars.buttons["Edit"], called: "Edit")
        let field = try descriptionField(in: app)
        clear(field)
        field.tap()
        if !text.isEmpty { field.typeText(text) }
    }

    /// Empty a text field with backspaces, putting the caret at the end first.
    ///
    /// Two things make the obvious version wrong. An empty SwiftUI `TextField` reports its
    /// **placeholder** as its `value`, so the delete count has to come from a value that is really
    /// text. And a plain `tap()` lands the caret wherever it hit — mid-string on a field that
    /// already holds text — so the backspaces eat the middle and the following `typeText` inserts
    /// into the wreckage. Tapping the field's bottom-right corner puts the caret past the last
    /// character on the last line, which is the only position from which a count of deletes means
    /// what it says.
    ///
    /// It **asserts that it worked**, because a clear that silently half-ran would surface later as
    /// the save assertion failing — a sentence about the wrong feature.
    @MainActor
    private func clear(_ field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard let value = field.value as? String,
              !value.isEmpty, value != field.placeholderValue else { return }
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        let after = field.value as? String ?? ""
        XCTAssertTrue(after.isEmpty || after == field.placeholderValue,
                      "the Description field would not clear — it still reads “\(after)”",
                      file: file, line: line)
    }

    /// The Description field, matched on the identifier the app sets
    /// (`UITestHooks.routineDescriptionField`) **across every element type**.
    ///
    /// `app.textFields[…]` is the obvious query and it finds nothing: a `TextField(axis: .vertical)`
    /// is exposed as a **text view**, so the typed query fails with "no Description field" — a
    /// sentence about the wrong thing, which cost one CI-length run to read. Matching any descendant
    /// by identifier is indifferent to which of the two SwiftUI picks, now or after an OS update.
    @MainActor
    private func descriptionField(in app: XCUIApplication) throws -> XCUIElement {
        let field = app.descendants(matching: .any)
            .matching(identifier: UITestHooks.routineDescriptionField).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout),
                      "no Description field in edit mode")
        XCTAssertTrue(scrollIntoView(field, in: app), "the Description field is not reachable")
        return field
    }
}
