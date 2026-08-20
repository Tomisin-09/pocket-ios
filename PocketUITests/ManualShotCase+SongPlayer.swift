import XCTest

/// The one route two shot classes share: Home ▸ Song library ▸ **Slow Bend**.
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

    /// Open Slow Bend for practice.
    ///
    /// **Three things here are not the house pattern.**
    ///
    /// *The row is revealed before it is queried.* Slow Bend is fifth of six by title, so it is not
    /// merely below the fold — it is absent from the accessibility tree until the list is swiped.
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
    func openSlowBend(in app: XCUIApplication,
                      file: StaticString = #filePath, line: UInt = #line) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Song library card on Home.\n\(stepLog)", file: file, line: line)
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Library"])

        let back = app.buttons["Back to library"]
        for attempt in 1...2 {
            let row = revealRow(labelStartingWith: "Slow Bend", in: app, file: file, line: line)
            guard awaitHittable(row) else {
                XCTFail("""
                    the Slow Bend row never became hittable, so the tap could not be synthesised.
                    \(stepLog)
                    """, file: file, line: line)
                return
            }
            row.tap()
            note("tapped Slow Bend"
                 + (attempt > 1 ? " (attempt \(attempt))" : "")
                 + " — waiting up to \(Int(Self.playerOpenTimeout))s for the audio to load")

            if back.waitForExistence(timeout: Self.playerOpenTimeout) {
                note("the player is open")
                return
            }
            guard row.exists && row.isHittable else {
                XCTFail("""
                    tapped Slow Bend, the row is no longer reachable, and the player never opened — \
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
}
