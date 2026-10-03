import XCTest

/// The one route two shot classes share: Home ▸ Song library ▸ **Binta**, the song every player figure
/// is shot on. It was Slow Bend until 2026-10-03, whose waveform is drawn in code and looks like no song
/// (`ScreenshotSeed+Binta`); Binta's is its real audio.
///
/// `ManualPlayerShots` photographs the player and `ManualLoopSheetShots` photographs the sheets that
/// open from it, and both have to get there. It lives here rather than being written twice because
/// the two things that make it awkward are subtle enough that a second copy would drift from the
/// first — which it did: the copy in the loop-sheet class failed on a run where the identical copy in
/// the player class passed six times.
extension ManualShotCase {

    /// How long to wait for the player to open.
    ///
    /// Much longer than a screen transition, because it is not one: opening a song decodes its audio,
    /// and on a device erased minutes earlier that is the slowest single step in the shoot.
    static var playerOpenTimeout: TimeInterval { 90 }

    /// Open the hero song, Binta, for practice.
    ///
    /// **Three things here are not the house pattern.**
    ///
    /// *The row is revealed before it is queried.* Binta is first by title, but `revealRow` costs
    /// nothing when the row is in view, and Slow Bend — fifth of six — needed it: absent from the
    /// accessibility tree until the list is swiped.
    ///
    /// *The tap is not `tap(_:revealing:)`.* That helper retries while the control it tapped is still
    /// reachable, and reads "the control is gone but the destination never arrived" as proof that
    /// something else opened. Here the destination legitimately takes up to a minute, and the moment
    /// the player begins presenting, the row it came from is covered — so the helper calls a player
    /// that is opening perfectly well a failure. That is exactly what it did the first three times
    /// this route was walked: `MISS 'Slow Bend' — in the tree but not hittable`, reported from a
    /// screen where the player was already on top.
    ///
    /// *It retries once, on evidence.* A single attempt failed once in seven on an otherwise green
    /// run, with the row still sitting there afterwards — a tap synthesised into a list that was
    /// still decelerating from the reveal swipe. A retry is only taken when the row is **still
    /// hittable**, which means nothing opened and there is nothing to be confused about; if the row
    /// is covered, something did open and this fails rather than tapping blind into it.
    @MainActor
    func openHeroSong(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        openSong(Self.heroSong, in: app, file: file, line: line)
    }

    /// Open `title` for practice, the same way: the map pass's figures stay on its mapped Slow Bend.
    @MainActor
    func openSong(_ title: String, in app: XCUIApplication,
                  file: StaticString = #filePath, line: UInt = #line) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Song library card on Home.\n\(stepLog)", file: file, line: line)
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Library"])

        let back = app.buttons["Back to library"]
        for attempt in 1...2 {
            let row = revealRow(labelStartingWith: title, in: app, file: file, line: line)
            guard awaitHittable(row) else {
                XCTFail("""
                    the \(title) row never became hittable, so the tap could not be synthesised.
                    \(stepLog)
                    """, file: file, line: line)
                return
            }
            row.tap()
            note("tapped \(title)"
                 + (attempt > 1 ? " (attempt \(attempt))" : "")
                 + " — waiting up to \(Int(Self.playerOpenTimeout))s for the audio to load")

            if back.waitForExistence(timeout: Self.playerOpenTimeout) {
                note("the player is open")
                return
            }
            guard row.exists && row.isHittable else {
                XCTFail("""
                    tapped \(title), the row is no longer reachable, and the player never opened — \
                    so something else is on screen and any capture from here would be of it.
                    \(stepLog)
                    """, file: file, line: line)
                return
            }
            note("tap \(attempt) changed nothing — the row is still there, retrying")
        }

        XCTFail("""
            the song player never opened within \(Int(Self.playerOpenTimeout))s, twice over.
            \(stepLog)
            """, file: file, line: line)
    }

    /// The song the player figures open. One constant, so the route and the figures' assertions name it
    /// once.
    static var heroSong: String { "Binta" }

    /// Home ▸ `Song library`. Shared: the library, map and send passes all start here.
    ///
    /// The card's label carries the song count (`Song library, 6 songs`), so it is matched by prefix
    /// — pinning the number here would make every library figure fail on a seed change rather than
    /// on the thing it is about. Arrival is the **Library** navigation bar: Home's card says the
    /// words "Song library", and a gate the screen you are leaving already satisfies is not a gate.
    @MainActor
    func openLibrary(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Song library card on Home.\n\(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Library"])
    }

    /// The song player's title strip, which a hold opens Song details from. `SongStrip` combines the
    /// title, the artist and, on a rated song, its mastery dots, so Feels reads `Feels, Jack Trader,
    /// Mastery 3 of 5` and an unrated song stops at the artist; an exact match on the first missed Feels
    /// (2026-10-03). Never a bare prefix: the library row under the player starts with the same words.
    @MainActor
    func playerTitle(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let strip = "\(title), Jack Trader"
        return app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@",
                                                strip, strip + ", Mastery")).firstMatch
    }

    /// Scroll the song player's panels up until `reached`. The drag runs from near the bottom of the
    /// screen to just under the transport, inside the panels, because a drag that starts on the waveform
    /// scrubs it rather than scrolling anything — which is also why `scrollIntoFrame`, which swipes from
    /// the middle, can't be used here.
    @MainActor
    func raisePanels(until reached: () -> Bool, called name: String, in app: XCUIApplication) {
        for pass in 0..<4 where !reached() {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.71))
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
            note("dragged the panels up (\(pass + 1))")
        }
        XCTAssertTrue(reached(), "never brought \(name) into reach under the waveform.\n\(stepLog)")
    }
}
