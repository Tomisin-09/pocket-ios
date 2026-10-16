import XCTest

/// The manual's figures of a song worked out note by note: the song map, the saved piece, Name the notes,
/// Watch it on the neck and the Journal's Pieces (ADRs 0225–0238, 0254). None of them draws the player's waveform; the Snags panel,
/// which does, moved to the player pass on Binta (2026-10-03).
///
/// **Its own pass, `map`, launched with `-seedSongMap`.** Every figure here is of the Slow Bend that
/// `SongMapPreview` lays out (sections, chords and notes pieces, a named riff) with three seeded snags,
/// one carrying a line. That song is not the demo song: it has six loops where the demo has two, and a
/// player figure shot beside it would show them. A pass is an erased device, so no other figure can.
///
/// Nothing here writes: the sheets are cancelled, and the segments are views of the same state.
final class ManualSongMapShots: ManualShotCase {

    /// `songs/song-map` · `songs/song-tab` — Song details ▸ Map the song, on Pieces and then on Tab.
    /// One test, because the second is the first with the segment moved.
    @MainActor
    func testSongMap() {
        let app = launchForShoot(seeding: [UITestHooks.songMapArgument])
        // Through the player's title rather than the library row's menu: a hold on the row, once it had
        // been swiped up into reach, opened nothing twice and then wasn't hittable (2026-10-03).
        openSong("Slow Bend", in: app)
        hold(playerTitle("Slow Bend", in: app), labelled: "the title",
             revealing: app.navigationBars["Song details"], called: "Song details")

        let map = app.buttons["Map the song"]
        scrollIntoFrame(map, called: "Map the song", in: app)
        let tabMode = app.segmentedControls.buttons["Tab"]
        tap(map, labelled: "Map the song", revealing: tabMode, called: "the song map")

        // The sections are the state the marker asks for; a map with no sections would offer to make
        // them from the markers instead, which is a different figure.
        capture(app, slug: "songs/song-map", assertingOnScreen: "Slow Bend",
                orBeginningWith: ["Intro", "Verse 1", "Chorus"])

        // Tapped until it takes: the first tap went unanswered for 30 s once (2026-10-03), with the map
        // still settling from the capture. `tap(_:revealing:)` can't do this: the segment stays put.
        let selected = NSPredicate(format: "isSelected == true")
        var onTab = false
        for attempt in 1...3 where !onTab {
            awaitHittable(tabMode)
            tabMode.tap()
            note("tapped Tab" + (attempt > 1 ? " (attempt \(attempt))" : ""))
            onTab = XCTWaiter().wait(for: [expectation(for: selected, evaluatedWith: tabMode)],
                                     timeout: 8) == .completed
        }
        XCTAssertTrue(onTab, "the map never moved to Tab.\n\(stepLog)")
        capture(app, slug: "songs/song-tab", assertingOnScreen: "Slow Bend",
                orBeginningWith: ["Verse 1"])
    }

    /// `reference/saved-piece` · `reference/name-the-notes` · `reference/name-by-ear` — the riff's saved
    /// piece under Train your ear, then Name the notes on each of its two sheets. Cancelled, not saved.
    @MainActor
    func testSavedPieceAndNaming() {
        let app = launchForShoot(seeding: [UITestHooks.songMapArgument])
        openVerseRiff(in: app)

        let train = app.buttons["Train your ear on this loop"]
        scrollIntoFrame(train, called: "Train your ear on this loop", in: app)
        tap(train, labelled: "Train your ear on this loop",
            revealing: app.navigationBars["Train your ear"], called: "Train your ear")

        // Scrolled until Name the notes, the last of the saved piece, is in frame, so its tab and its
        // snags are in view with it. The riff's first snag is on its fifth note and carries the line.
        let name = app.buttons["count.saved.name"]
        scrollPastTapPad(until: name, called: "Name the notes", in: app)
        capture(app, slug: "reference/saved-piece", assertingOnScreen: "Train your ear",
                alsoRequiring: ["count.saved.name", "Snags on this piece"],
                orBeginningWith: ["Saved on this loop", "Note 5 · \(ScreenshotSeedText.snagLine)"])

        let fret = app.segmentedControls.buttons["Fret & string"]
        tap(name, labelled: "Name the notes", revealing: fret, called: "Name the notes")
        capture(app, slug: "reference/name-the-notes", assertingOnScreen: "Name the notes",
                alsoRequiring: ["naming.chip.0"])

        let ear = app.segmentedControls.buttons["By ear"]
        ear.tap()
        note("tapped By ear")
        let onEar = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: ear)
        wait(for: [onEar], timeout: Self.shootTimeout)
        capture(app, slug: "reference/name-by-ear", assertingOnScreen: "Name the notes",
                alsoRequiring: ["naming.chip.0"])

        app.navigationBars["Name the notes"].buttons["Cancel"].tap()
        note("cancelled Name the notes")
    }

    /// `reference/watch-on-neck` — the riff's Edit loop ▸ Watch it on the neck, stopped (ADR 0254). Stopped
    /// is the state the marker asks for: the neck holds the whole lick, where a playing frame would light
    /// one note at whatever instant the shutter fell on.
    @MainActor
    func testWatchOnTheNeck() {
        let app = launchForShoot(seeding: [UITestHooks.songMapArgument])
        openVerseRiff(in: app)

        let title = "Watch it on the neck"
        let watch = app.buttons["loopEdit.watch"]
        scrollIntoFrame(watch, called: title, in: app)
        tap(watch, labelled: title, revealing: app.navigationBars[title], called: title)
        capture(app, slug: "reference/watch-on-neck", assertingOnScreen: title,
                alsoRequiring: ["watch.neck", "Play the loop"])

        app.navigationBars[title].buttons["Done"].tap()
        note("closed \(title)")
    }

    /// Slow Bend ▸ hold *Verse riff* ▸ Edit loop. The riff is the third of six loops, which leaves its row
    /// on the bottom edge, where a hold opened nothing and the row then wasn't hittable (2026-10-03).
    /// Raised clear of it first.
    @MainActor
    private func openVerseRiff(in app: XCUIApplication) {
        openSong("Slow Bend", in: app)
        let loop = app.buttons["Play Verse riff"]
        XCTAssertTrue(loop.waitForExistence(timeout: Self.shootTimeout), "no Verse riff row.\n\(stepLog)")
        let bottom = app.windows.firstMatch.frame.maxY - 80
        raisePanels(until: { loop.isHittable && loop.frame.maxY < bottom }, called: "the Verse riff row", in: app)
        hold(loop, labelled: "Verse riff", revealing: app.navigationBars["Edit loop"], called: "Edit loop")
    }

    /// `journal/pieces` — the Journal on **Pieces**, grouped by song with Map the song beside it.
    @MainActor
    func testJournalPieces() {
        let app = launchForShoot(seeding: [UITestHooks.songMapArgument])
        tapHomeCard("Journal, your notes and practice takes", in: app,
                    arrivingAt: app.buttons["Journal options"])

        let pieces = app.segmentedControls.buttons["Pieces"]
        XCTAssertTrue(pieces.waitForExistence(timeout: Self.shootTimeout),
                      "no Pieces in the Journal's scope control.\n\(stepLog)")
        pieces.tap()
        note("tapped Pieces")
        let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: pieces)
        wait(for: [selected], timeout: Self.shootTimeout)

        // Map the song is on a song's heading under Pieces and nowhere else in the Journal, so it proves
        // the list redrew as well as the segment moving.
        capture(app, slug: "journal/pieces", assertingOnScreen: "Journal",
                alsoRequiring: ["Map the song"], orBeginningWith: ["Slow Bend"])
    }

    /// `scrollIntoFrame` swipes from the middle of the screen, and under Train your ear the middle is
    /// soon Count the notes' tap pad, which takes a swipe as taps: the sheet stopped with the saved
    /// piece's heading in frame and its tab below (2026-10-03). So the drag starts on that heading, which
    /// sits under the pad and moves with the sheet, and only falls back to the middle once it's gone.
    @MainActor
    private func scrollPastTapPad(until element: XCUIElement, called name: String, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        let heading = app.staticTexts["Saved on this loop"]
        for pass in 0...8 {
            if element.exists, !element.frame.isEmpty, window.contains(element.frame) {
                note("'\(name)' is in frame" + (pass > 0 ? " after \(pass) drag(s)" : ""))
                return
            }
            if heading.exists, heading.isHittable {
                let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                heading.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .press(forDuration: 0.1, thenDragTo: top, withVelocity: .slow, thenHoldForDuration: 0.1)
            } else {
                app.swipeUp(velocity: .slow)
            }
        }
        XCTFail("never brought '\(name)' into the frame.\n\(diagnosis(for: name, in: app))\n\(stepLog)")
    }
}

/// Words the seed writes that a figure is gated on. Spelled here rather than read from the app, because
/// the shoot target doesn't link the app's DEBUG seed; kept equal to `ScreenshotSeed.snagLine`.
enum ScreenshotSeedText {
    static let snagLine = "The jump to the top string lands late."
    /// `ScreenshotSeed.bintaSnagLine`, the line under Binta's first snag, in the player pass's Snags panel.
    static let bintaSnagLine = "The change into bar 11 comes in late."
}
