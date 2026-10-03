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

        // Played once first. The seed links each song to its file the pre-0148 way, and a linked song
        // gets Red Moon's own copy the first time it plays; until then the Audio row reads `Linked
        // file`, a state only a library from before 0148 is ever in. Played, it reads as an import does.
        let back = app.buttons["Back to library"]
        tap(row, labelled: "Feels", revealing: back, called: "the song player")
        tap(back, labelled: "Back to library", revealing: app.navigationBars["Library"], called: "the library")

        hold(row, labelled: "the Feels row",
             revealing: app.buttons["Details"], called: "the row menu")
        tap(app.buttons["Details"], labelled: "Details",
            revealing: app.navigationBars["Song details"], called: "the Song details sheet")

        // The File row's value, `WAV ·`, and not just the row: `SongAudioLabel.describe` returns
        // `Missing` for a song with no copy behind it, and the row is present and correct-looking either
        // way. The row's `LabeledContent` once read as one element, `File, WAV · 8.9 MB`, and reads as
        // two since (2026-10-03), so each half is asserted. The size is left off because it moves with
        // the seed audio; the format does not. Map the song (ADR 0232) sits above Audio and leaves the
        // File row the last whole one in frame, which the alt text says.
        capture(app, slug: "reference/song-details",
                assertingOnScreen: "Song details",
                alsoRequiring: ["File", "Map the song"],
                orBeginningWith: ["Feels", "WAV ·"])
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
        //
        // Found by its **placeholder**, the same trap as the four above: `Add a collection` is the
        // prompt of an empty `TextField`, not its label, so a label query never finds it and the
        // scroll used to run out of swipes on a row that was on screen. Gated on the row's own `Add`.
        let addRow = app.textFields
            .matching(NSPredicate(format: "placeholderValue == %@", "Add a collection")).firstMatch
        scrollIntoFrame(addRow, called: "the Add a collection row", in: app)

        capture(app, slug: "songs/song-edit",
                assertingOnScreen: "Edit song",
                alsoRequiring: ["Collections", "Add"])
    }
}
