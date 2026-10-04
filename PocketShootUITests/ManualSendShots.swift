import XCTest

/// The manual's figures of a song or a routine leaving and arriving (ADR 0236): **Send this song**,
/// **Add this song?**, **Add this routine?** and **Send this routine**.
///
/// **Its own pass, `send`.** The routine test lands a routine and its song (that is the only way to a
/// routine whose song can go), and a pass is an erased device, so nothing else sees them.
///
/// The packs are `ReceivedPackSeed`'s, which under `-seedScreenshots` are the manual's rather than the
/// suite's: Slow Bend sent by Jack Trader, and *Low Road, start to finish* with *Low Road* in it.
final class ManualSendShots: ManualShotCase {

    /// `songs/send-song` — Song details ▸ Send this song…, on Feels. The song is played first, because a
    /// seeded song is linked to its file until it plays (`SongAudioResolver.adoptIfNeeded`), and Send
    /// needs Red Moon's own copy.
    @MainActor
    func testSendSong() {
        let app = launchForShoot()
        openLibrary(in: app)

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Feels,")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.shootTimeout), "no Feels row.\n\(stepLog)")
        let back = app.buttons["Back to library"]
        tap(row, labelled: "Feels", revealing: back, called: "the song player")

        let title = playerTitle("Feels", in: app)
        let details = app.navigationBars["Song details"]
        hold(title, labelled: "the title", revealing: details, called: "Song details")

        let send = app.buttons["Send this song…"]
        scrollIntoFrame(send, called: "Send this song…", in: app)
        tap(send, labelled: "Send this song…", revealing: app.navigationBars["Send this song"],
            called: "Send this song")
        capture(app, slug: "songs/send-song", assertingOnScreen: "Send this song",
                alsoRequiring: ["Send…"])
    }

    /// `songs/receive-song` — **Add this song?** for a Slow Bend sent by Jack Trader, with the copy-name
    /// note, since the library already has one. Cancelled: nothing lands.
    @MainActor
    func testReceiveSong() {
        let app = seededThenRelaunched(with: UITestHooks.receivePackArgument)
        let preview = app.navigationBars["Add this song?"]
        XCTAssertTrue(preview.waitForExistence(timeout: Self.shootTimeout),
                      "the pack didn't open on the receive door.\n\(stepLog)")
        capture(app, slug: "songs/receive-song", assertingOnScreen: "Add this song?",
                orBeginningWith: ["Sent by Jack Trader"])
        preview.buttons["Cancel"].tap()
        note("cancelled")
    }

    /// `routines/receive-routine` · `routines/send-routine` — **Add this routine?** with its Songs list,
    /// then, once added, the routine's own **Send this routine** with *Include the songs* on. One test:
    /// the second is of what the first lands.
    @MainActor
    func testReceiveAndSendRoutine() {
        let app = seededThenRelaunched(with: UITestHooks.receiveRoutinePackArgument)
        let preview = app.navigationBars["Add this routine?"]
        XCTAssertTrue(preview.waitForExistence(timeout: Self.shootTimeout),
                      "the pack didn't open on the receive door.\n\(stepLog)")
        capture(app, slug: "routines/receive-routine", assertingOnScreen: "Add this routine?",
                orBeginningWith: ["Low Road"])

        let added = app.alerts["Added"]
        tap(preview.buttons["Add"], labelled: "Add", revealing: added, called: "the Added alert")
        for _ in 0..<3 where added.exists {
            added.buttons["OK"].tap()
            _ = added.waitForNonExistence(timeout: 3)
        }
        XCTAssertFalse(added.exists, "the Added alert never closed.\n\(stepLog)")
        note("added the routine")

        let practice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: Self.shootTimeout), "no Practice card.\n\(stepLog)")
        tapHomeCard(practice.label, in: app, arrivingAt: app.navigationBars["Practice"])
        tapRow(labelStartingWith: "Routines,", in: app,
               arrivingAt: app.navigationBars["Routines"], called: "the Routines library")
        let name = "Low Road, start to finish"
        let routine = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(routine.waitForExistence(timeout: Self.shootTimeout), "the routine didn't land.\n\(stepLog)")
        tap(routine, labelled: name, revealing: app.navigationBars[name], called: "the routine")

        let share = app.navigationBars.buttons["Send this routine"]
        tap(share, labelled: "Send this routine", revealing: app.navigationBars["Send this routine"],
            called: "Send this routine")
        capture(app, slug: "routines/send-routine", assertingOnScreen: "Send this routine",
                alsoRequiring: ["Include the songs", "Send…"])
    }

    /// Launch once so the seed has written the library, then again with a pack: the pack opens in a
    /// launch task, and on a first launch it could be read before Slow Bend is in the store, which would
    /// lose the copy-name note.
    @MainActor
    private func seededThenRelaunched(with pack: String) -> XCUIApplication {
        let first = launchForShoot()
        first.terminate()
        note("seeded, then relaunched with \(pack)")
        return launchForShoot(seeding: [pack])
    }
}
