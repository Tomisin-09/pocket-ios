import XCTest

/// The manual's My tabs figures (ADR 0235): the writer mid-tab, the list with that tab, and the tab
/// open to read.
///
/// **Its own pass, `tabs`**, because it writes: every figure is of a tab this test wrote, and a written tab would sit in the list of any other figure on the same device. **One test**,
/// because each figure is the state the one before it built, and across tests the order would be
/// XCTest's to pick.
///
/// The tab is an A minor pentatonic run in two sections, Intro and Verse, with a bar line in each: the
/// smallest tab that shows every part the page names (sections, bar lines, the strip's + slot).
final class ManualTabShots: ManualShotCase {

    private static let title = "Pentatonic run"

    @MainActor
    func testMyTabs() {
        let app = launchForShoot()
        let toolkit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Toolkit,")).firstMatch
        XCTAssertTrue(toolkit.waitForExistence(timeout: Self.shootTimeout), "no Toolkit card on Home.\n\(stepLog)")
        tapHomeCard(toolkit.label, in: app, arrivingAt: app.navigationBars["Toolkit"])
        tapRow(labelStartingWith: "My tabs,", in: app,
               arrivingAt: app.navigationBars["My tabs"], called: "My tabs")

        // 1. The writer, part-way through a tab. (The empty list isn't a figure: it is the two phrases
        // the page already quotes, *No tabs yet* and *Write a tab*.)
        let newTab = app.navigationBars["My tabs"].buttons["New tab"]
        tap(newTab, labelled: "New tab", revealing: app.navigationBars["New tab"], called: "the writer")
        nameTheTab(in: app)
        section("Intro", in: app)
        write(["A string, fret 5,", "A string, fret 7,", "D string, fret 5,", "D string, fret 7,"], in: app)
        barLine(in: app)
        write(["G string, fret 5,", "G string, fret 7,", "B string, fret 5,", "B string, fret 8,"], in: app)
        section("Verse", in: app)
        write(["e string, fret 5,", "e string, fret 8,", "B string, fret 8,", "B string, fret 5,"], in: app)
        barLine(in: app)
        write(["G string, fret 7,", "G string, fret 5,", "D string, fret 7,"], in: app)
        capture(app, slug: "toolkit/tab-writer", assertingOnScreen: "New tab",
                alsoRequiring: ["tab.slot", "tab.chip.14"])

        // 2. The list, holding it.
        let done = app.navigationBars["New tab"].buttons["Done"]
        tap(done, labelled: "Done", revealing: app.navigationBars["My tabs"], called: "My tabs")
        capture(app, slug: "toolkit/my-tabs", assertingOnScreen: "My tabs",
                orBeginningWith: [Self.title])

        // 3. Open to read.
        let row = element(in: app, labelStartingWith: Self.title)
        tap(row, labelled: Self.title, revealing: app.buttons["tab.edit"], called: "the tab")
        // The reading screen draws its title in the content and leaves the bar empty, so it is gated on
        // what it owns: Edit, and the title as text.
        captureChromeless(app, slug: "toolkit/tab-read", screen: "the tab, open to read",
                          ownedBy: ["tab.edit", Self.title])
    }

    // MARK: - Writing

    /// Typed, then submitted, so the keyboard is down before the neck is tapped: it covers the neck.
    ///
    /// The tap waits for the focus rather than assuming it, as `TemporarySessionUITests.focusAtEnd`
    /// does: the first run tapped the field as the writer arrived and `typeText` found nothing focused.
    @MainActor
    private func nameTheTab(in app: XCUIApplication) {
        let field = app.textFields["tab.title"]
        XCTAssertTrue(field.waitForExistence(timeout: Self.shootTimeout), "no title field.\n\(stepLog)")
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        var took = false
        for _ in 0..<3 where !took {
            field.tap()
            took = XCTWaiter().wait(for: [expectation(for: focused, evaluatedWith: field)], timeout: 3) == .completed
        }
        XCTAssertTrue(took, "the title field never took keyboard focus.\n\(stepLog)")
        field.typeText(Self.title)
        XCTAssertEqual(field.value as? String, Self.title, "the name didn't land as typed.\n\(stepLog)")
        note("named the tab '\(Self.title)'")

        // Return ends editing; the keyboard's own Done key if it didn't (the second run's keyboard stayed
        // up after a `\n` typed on XCTest's retry).
        field.typeText("\n")
        let down = expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.keyboards)
        if XCTWaiter().wait(for: [down], timeout: 5) != .completed {
            app.keyboards.buttons.matching(NSPredicate(format: "label ==[c] %@", "done")).firstMatch.tap()
            note("pressed the keyboard's Done")
            let gone = expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.keyboards)
            wait(for: [gone], timeout: Self.shootTimeout)
        }
    }

    /// Each tap is checked by the chip it fills, so a swallowed tap fails here rather than leaving a
    /// tab one note short that photographs as cleanly as the right one.
    ///
    /// **One retry, then an exact count.** A loaded machine lost the twelfth tap of fifteen outright
    /// (2026-10-03), so a spot that fills nothing in 8 s is tapped again. That second tap is the risk —
    /// if the first was only slow, both land — so the count is then held to exactly one more than
    /// before: a doubled note fails here instead of being photographed as the tab.
    @MainActor
    private func write(_ spots: [String], in app: XCUIApplication) {
        for prefix in spots {
            let filled = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'tab.chip.'"))
            let before = filled.count
            let spot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
            XCTAssertTrue(spot.waitForExistence(timeout: Self.shootTimeout), "no \(prefix) on the neck.\n\(stepLog)")
            let grew = NSPredicate(format: "count > %d", before)
            var landed = false
            for attempt in 1...2 where !landed {
                awaitHittable(spot)
                spot.tap()
                landed = XCTWaiter().wait(for: [expectation(for: grew, evaluatedWith: filled)],
                                          timeout: attempt == 1 ? 8 : Self.shootTimeout) == .completed
                if !landed { note("tap on \(prefix) filled nothing, retrying") }
            }
            sleep(1)
            XCTAssertEqual(filled.count, before + 1, "\(prefix) didn't write exactly one note.\n\(stepLog)")
            note("wrote \(prefix) — chip \(before + 1)")
        }
    }

    @MainActor
    private func barLine(in app: XCUIApplication) {
        app.buttons["tab.barLine"].tap()
        let bar = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Bar line before the next note you write")).firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: Self.shootTimeout), "no bar line in the strip.\n\(stepLog)")
        note("bar line")
    }

    @MainActor
    private func section(_ name: String, in app: XCUIApplication) {
        let choice = app.buttons[name]
        tap(app.buttons["tab.section"], labelled: "Section", revealing: choice, called: "the section names")
        choice.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name))
                        .firstMatch.waitForExistence(timeout: Self.shootTimeout),
                      "no \(name) heading in the strip.\n\(stepLog)")
        note("section \(name)")
    }
}
