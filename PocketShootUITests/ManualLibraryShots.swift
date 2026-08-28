import XCTest

/// The manual's **Song library** figures (ADR 0165, Phase 5) — the list itself, and the two sheets
/// that hang off a row.
///
/// Read-only: nothing here saves an edit, imports a file or deletes a row, so this class rides in
/// the `library` pass on a device it leaves exactly as it found it.
///
/// **It used to shoot three menus as well** — the sort menu, the collection filter and the menu a
/// held row opens — and their markers were cut from the prose in Phase 5 rather than reshot. Each
/// was a picture of a list of words the page beside it already listed, which is the one thing ADR
/// 0165 says a figure should never be. The tests went with the markers: a `capture()` of a slug no
/// marker defines fails C13, so a cut that stops at the prose leaves the check red.
///
/// **Two things about this screen decided how every test below is written.**
///
/// The list is sorted by **Title** on arrival, so `reference/library`'s "sorted by title" state
/// needs no tap at all — it is asserted rather than set, because a figure whose state is a default
/// is one app change away from being a figure of something else.
///
/// And **Slow Bend is below the fold.** It is the fifth of six songs by title, so it is not merely
/// off-screen but absent from the accessibility tree — which is why `testSongEdit` puts `revealRow`
/// in front of the hold, and a query that simply asked for the row would report a library that has
/// it as a library that does not.
final class ManualLibraryShots: ManualShotCase {

    /// `reference/library` · `songs/library-row` — the grouped list, and the row crop taken from it.
    ///
    /// One frame, two markers: the reference figure is the whole screen and `songs/library-row` is a
    /// `role: detail` crop of the **Feels** row inside it. Sharing is only legitimate when the crop's
    /// subject is provably in the picture, so the Feels row is required in frame rather than assumed
    /// — it is the second song of six, and a seed that lost one would slide it out of shot without
    /// changing anything else the figure asserts.
    ///
    /// The sort control is asserted with its full label because it carries the state: `Sort by Title,
    /// ascending` is the whole of "sorted by title" as the app expresses it. The lettered headers are
    /// what the figure is *of* — a list that had lost its grouping would still show rows.
    @MainActor
    func testLibrary() {
        let app = launchForShoot()
        openLibrary(in: app)
        capture(app, slug: "reference/library",
                assertingOnScreen: "Library",
                alsoRequiring: ["Sort by Title, ascending"],
                // `B,` and `F,` are the lettered headers; neither can be satisfied by the row under
                // it, because `Binta,` does not begin `B,`. Written without their counts on purpose
                // — a header's count moves with the seed, and this figure is about the grouping.
                orBeginningWith: ["B,", "F,", "Feels, Jack Trader"],
                alsoServing: ["songs/library-row"])
    }

    /// `reference/song-details` — the Song details sheet.
    ///
    /// **Shot on Feels, and Slow Bend is why.** This was on Slow Bend until a hand re-shoot in Phase
    /// 5 put the resulting frame in front of a pair of eyes: its `Audio` section read `File:
    /// Missing`. Slow Bend is the bundled tone-generator demo, the one seeded song with no bookmark
    /// and no file behind it, so the figure that exists to show the audio section was showing that
    /// section's failure state — a true picture of the wrong song. The marker's alt text names the
    /// file row, so this must be a song that has one.
    ///
    /// Feels is second of six by title and therefore already in the tree, which is also why the
    /// swipe that Slow Bend needed is gone.
    @MainActor
    func testSongDetails() {
        let app = launchForShoot()
        openLibrary(in: app)

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Feels,")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.shootTimeout),
                      "no Feels row to hold.\n\(stepLog)")
        hold(row, labelled: "the Feels row",
             revealing: app.buttons["Details"], called: "the row menu")
        tap(app.buttons["Details"], labelled: "Details",
            revealing: app.navigationBars["Song details"], called: "the Song details sheet")

        // `File, WAV` rather than `File`: the row is a `LabeledContent`, so the label and its value
        // combine into one element reading "File, WAV · 8.9 MB". Asserting the value and not just
        // the row is the point — `SongAudioLabel.describe` returns `Missing` for a song with no
        // copy behind it, and that row is present and correct-looking either way. The size is left
        // off because it moves with the seed audio; the format does not.
        capture(app, slug: "reference/song-details",
                assertingOnScreen: "Song details",
                orBeginningWith: ["Feels", "File, WAV"])
    }

    /// `reference/song-edit` · `songs/song-edit` — the Edit song sheet, top and scrolled.
    ///
    /// **Two markers, two frames, one test.** They are different states of one sheet — the reference
    /// figure is the Details section (title through downbeat and the key picker), and the songs
    /// figure is the same sheet scrolled to Collections — so they cannot share a frame, and building
    /// the second means having built the first. Shooting them in sequence in one test is the only way
    /// to guarantee the order; across two tests it would be XCTest's to choose.
    ///
    /// Nothing is saved: the sheet commits on **Done**, and this never taps it.
    @MainActor
    func testSongEdit() {
        let app = launchForShoot()
        openLibrary(in: app)

        let row = revealRow(labelStartingWith: "Slow Bend", in: app)
        hold(row, labelled: "the Slow Bend row",
             revealing: app.buttons["Edit"], called: "the row menu")
        tap(app.buttons["Edit"], labelled: "Edit",
            revealing: app.navigationBars["Edit song"], called: "the Edit song sheet")

        // **`Title`, `Artist`, `Album` and `Genre` are placeholders, not labels** — this asserted
        // all four for months and could never have passed. `SongEditSheet` builds them as
        // `ClearableTextField("Title", text: $title)`, where the string is the prompt: it is in the
        // tree only while the field is *empty*, and on a seeded song every one of them holds a
        // value. The test was demanding evidence that the sheet had failed to load the song.
        //
        // `Year`, `BPM` and `Downbeat (s)` are `NumberRow(label:)` and stay whatever the field
        // holds, so they are the rows that can be asserted. `Downbeat (s)` is the last of the
        // section, which is what proves the frame reaches the bottom of what the alt text lists.
        capture(app, slug: "reference/song-edit",
                assertingOnScreen: "Edit song",
                alsoRequiring: ["Details", "Year", "BPM", "Downbeat (s)"])

        // Then the same sheet, scrolled. Aimed at `Add a collection`, the last row of the section —
        // stopping at the header would leave the chips the figure is of below the fold.
        scrollIntoFrame(element(in: app, labelStartingWith: "Add a collection"),
                        called: "the Add a collection row", in: app)

        capture(app, slug: "songs/song-edit",
                assertingOnScreen: "Edit song",
                alsoRequiring: ["Collections", "Add a collection"])
    }

    // MARK: - Navigation

    /// Home ▸ `Song library`.
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
}
