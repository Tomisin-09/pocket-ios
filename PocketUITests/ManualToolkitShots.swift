import XCTest

/// The manual's **Toolkit** figures (ADR 0165, Phase 5) — the hub, My chords, the Glossary and the FAQs.
///
/// The Tuner is not here. It needs a microphone hearing a real string, which a simulator cannot
/// provide, so `toolkit/tuner` and `reference/tuner` are `device:` shots — see `docs/manual/README.md`.
///
/// `toolkit/hub` asks for "some saved chords present" and `toolkit/my-chords` for "three or more". A
/// `SavedChord` is only ever written by the custom placer at runtime, so `ScreenshotSeed` has none;
/// `PracticeHistorySeed` writes four. Without that, both figures shoot cleanly and both show *none
/// saved* — the wrong state, photographed perfectly.
final class ManualToolkitShots: ManualShotCase {

    /// `toolkit/hub` · `reference/toolkit` — the four sections, each with its count or state.
    @MainActor
    func testToolkitHub() {
        let app = launchForShoot()
        openToolkit(in: app)
        // The row reads "My chords, N saved". Requiring the count rather than the row proves the seed
        // landed: with no saved chords the screen is identical but for these few words.
        capture(app, slug: "toolkit/hub",
                assertingOnScreen: "Toolkit",
                orBeginningWith: ["My chords, 4 saved"],
                alsoServing: ["reference/toolkit"])
    }

    /// `toolkit/my-chords` — the grid of saved diagrams, newest first.
    @MainActor
    func testMyChords() {
        let app = launchForShoot()
        openToolkit(in: app)
        tapRow(labelStartingWith: "My chords", in: app,
               arrivingAt: app.navigationBars["My chords"], called: "the My chords screen")
        // `Em7` is the newest of the four seeded voicings and therefore the first cell in the grid.
        // Asserting a chord *name* rather than the nav title is what distinguishes the populated grid
        // from the empty state, which carries the same title.
        capture(app, slug: "toolkit/my-chords",
                assertingOnScreen: "My chords",
                orBeginningWith: ["Em7"])
    }

    /// `toolkit/glossary` — the terms list, no search.
    @MainActor
    func testGlossary() {
        let app = launchForShoot()
        openToolkit(in: app)
        tapRow(labelStartingWith: "Glossary", in: app,
               arrivingAt: app.navigationBars["Glossary"], called: "the Glossary screen")
        capture(app, slug: "toolkit/glossary", assertingOnScreen: "Glossary")
    }

    /// `toolkit/faq` — the help list with one question expanded.
    ///
    /// The expansion is the whole subject of the figure: closed, this screen is indistinguishable from
    /// the Glossary at a glance, which is exactly why the marker specifies "one question expanded".
    @MainActor
    func testFAQ() {
        let app = launchForShoot()
        openToolkit(in: app)
        // The row's label spells the ampersand out — "Help and FAQs" — while the screen it opens is
        // titled "Help & FAQs". Matching the written form finds nothing.
        tapRow(labelStartingWith: "Help and FAQs", in: app,
               arrivingAt: app.navigationBars["Help & FAQs"], called: "the Help & FAQs screen")

        let question = app.descendants(matching: .any)["What is Red Moon Practice?"].firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: Self.shootTimeout),
                      "the first FAQ question never appeared. \(stepLog)")
        question.tap()
        note("tapped the first question")

        // Matched by prefix: the answer is a paragraph assembled from four concatenated string
        // literals and wrapped across however many lines the layout gives it.
        //
        // **This is app copy, and `FAQEntry.all` owns it.** The prefix below went stale in 1ab4ff2
        // (the positioning reframe rewrote the answer) and nothing noticed until a shoot failed on
        // it three days later, after fifteen minutes of driving — a failed shoot never reaches the
        // filing step, so the whole run produced nothing. Asserting on the *question* instead would
        // never go stale, and would also never fail: the question is on screen before the tap, so a
        // swallowed tap would photograph a collapsed row and pass. The answer is the only thing
        // that proves the row opened, so it stays, and it stays copy-bound on purpose.
        capture(app, slug: "toolkit/faq",
                assertingOnScreen: "Help & FAQs",
                orBeginningWith: ["A practice room that runs on music you already own"])
    }

    // MARK: - Navigation

    /// Home ▸ `Toolkit`.
    ///
    /// Matched on the label *prefix* `Toolkit,` — with the comma — because the card's subtitle has been
    /// rewritten three times as the hub grew ("chords, scales and theory reference" → "tuner, your
    /// chords and a glossary") and a full-label match makes this brittle to copy edits. The comma is
    /// what stops the prefix also matching the hub's own nav title once we are inside it.
    ///
    /// Home groups its strips into titled sections (ADR 0102) and Toolkit sits in "Your stuff", below
    /// the fold — hence the scroll, which `tapHomeCard` does slowly for reasons written up there.
    @MainActor
    private func openToolkit(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Toolkit,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Toolkit card on Home. \(stepLog)")
        // Arrival is the hub's **navigation bar**, not the text "Toolkit" — Home's card carries that
        // word too, and a gate a screen can satisfy before you reach it is not a gate.
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Toolkit"])
    }
}
