import XCTest

/// The manual's **Song library** figures (ADR 0165, Phase 5) — the list itself, its two toolbar
/// menus, and the menu a held row opens.
///
/// Read-only: nothing here saves an edit, imports a file or deletes a row, so this class rides in
/// the `library` pass on a device it leaves exactly as it found it. The library figures that *do*
/// change the store — the import picker, its progress band, and the undo toast after a delete — are
/// not here for that reason; they author, and a pass is one erased device.
///
/// **Two things about this screen decided how every test below is written.**
///
/// The list is sorted by **Title** on arrival, so `reference/library`'s "sorted by title" state
/// needs no tap at all — it is asserted rather than set, because a figure whose state is a default
/// is one app change away from being a figure of something else.
///
/// And **Slow Bend is below the fold.** It is the fifth of six songs, so it is not merely off-screen
/// but absent from the accessibility tree, which is why the sheets that hang off it live in
/// `ManualLibrarySheetShots` with `revealRow` in front of them rather than here.
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

    /// `songs/sort-menu` — the sort menu open over the library.
    ///
    /// Every option is required in frame, which is more than a gate: the marker's alt text lists all
    /// six categories and both directions, so a menu that had lost one would make the sentence beside
    /// the image false. `Title` and `Ascending` also carry `Selected`, which is what the library
    /// underneath is actually sorted by — the figure and `reference/library` agree by construction.
    ///
    /// The screen assertion is still `Library`: a menu draws over the navigation bar's screen rather
    /// than replacing it, so the bar is the right thing to prove we never left.
    @MainActor
    func testSortMenu() {
        let app = launchForShoot()
        openLibrary(in: app)

        let sort = app.buttons["Sort by Title, ascending"]
        tap(sort, labelled: "the sort control",
            revealing: app.buttons["Recently Added"], called: "the sort menu")

        capture(app, slug: "songs/sort-menu",
                assertingOnScreen: "Library",
                alsoRequiring: ["Mastery", "Recently Added", "Title", "Artist", "Album", "Genre",
                                "Ascending", "Descending"])
    }

    /// `reference/library-row-menu` · `gestures/row-hold-menu` — the menu a held row opens.
    ///
    /// **Binta**, because it is the first song in the list and therefore the one row that is in the
    /// tree the moment the screen arrives — a figure of a hold gesture should not also be a test of
    /// scrolling.
    ///
    /// Gated on `Delete`, the last of the three items, rather than on `Details`. The menu builds top
    /// down, so waiting on the first item can return with the rest still arriving, and this figure is
    /// of all three.
    @MainActor
    func testRowHoldMenu() {
        let app = launchForShoot()
        openLibrary(in: app)

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Binta,")).firstMatch
        hold(row, labelled: "the Binta row",
             revealing: app.buttons["Delete"], called: "the row menu")

        capture(app, slug: "reference/library-row-menu",
                assertingOnScreen: "Library",
                alsoRequiring: ["Details", "Edit", "Delete"],
                alsoServing: ["gestures/row-hold-menu"])
    }

    /// `songs/filter-menu` — the collection filter with two ticked.
    ///
    /// **The filter control renames itself as it works**, which is what made this the fiddliest of
    /// the library figures. It is `Filter by collection` with nothing selected, `Filtering by 1
    /// collection` after one, and `Filtering by any of 2 collections` after two — so re-opening the
    /// menu between ticks means asking for a *different* control each time, and an explore walk that
    /// asked twice for the first name reported the second collection as missing from a screen that
    /// had it.
    ///
    /// The relation in that last label is the figure's subject as much as the ticks are: ADR 0159
    /// made the filter OR within a facet, and "any of" is the app saying so.
    @MainActor
    func testFilterMenu() {
        let app = launchForShoot()
        openLibrary(in: app)

        tickCollection("chill", openingWith: "Filter by collection", in: app)
        tickCollection("blues", openingWith: "Filtering by 1 collection", in: app)

        let reopen = app.buttons["Filtering by any of 2 collections"]
        tap(reopen, labelled: "the filter control with two ticked",
            revealing: app.buttons["Clear filter"], called: "the filter menu")

        // `Clear filter` only exists once something is selected, so requiring it proves the ticks
        // took — a menu photographed with nothing selected is the same picture otherwise.
        capture(app, slug: "songs/filter-menu",
                assertingOnScreen: "Library",
                alsoRequiring: ["Clear filter", "chill", "blues"])
    }

    /// `reference/song-details` — the Song details sheet.
    ///
    /// Shot on **Slow Bend**, which the shoot list names and which is below the fold — fifth of six
    /// by title, so absent from the tree until the list is swiped.
    @MainActor
    func testSongDetails() {
        let app = launchForShoot()
        openLibrary(in: app)

        let row = revealRow(labelStartingWith: "Slow Bend", in: app)
        hold(row, labelled: "the Slow Bend row",
             revealing: app.buttons["Details"], called: "the row menu")
        tap(app.buttons["Details"], labelled: "Details",
            revealing: app.navigationBars["Song details"], called: "the Song details sheet")

        capture(app, slug: "reference/song-details",
                assertingOnScreen: "Song details",
                orBeginningWith: ["Slow Bend"])
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

        // `Downbeat (s)` is the last row of the Details section, so requiring it is what proves the
        // frame reaches the bottom of what the marker's alt text lists rather than stopping at Genre.
        capture(app, slug: "reference/song-edit",
                assertingOnScreen: "Edit song",
                alsoRequiring: ["Details", "Title", "Artist", "Album", "Genre", "Year", "BPM",
                                "Downbeat (s)"])

        // Then the same sheet, scrolled. Aimed at `Add a collection`, the last row of the section —
        // stopping at the header would leave the chips the figure is of below the fold.
        scrollIntoFrame(element(in: app, labelStartingWith: "Add a collection"),
                        called: "the Add a collection row", in: app)

        capture(app, slug: "songs/song-edit",
                assertingOnScreen: "Edit song",
                alsoRequiring: ["Collections", "Add a collection"])
    }

    // MARK: - Steps

    /// Open the filter menu by whatever it is currently called, and tick one collection.
    @MainActor
    private func tickCollection(_ collection: String,
                                openingWith control: String,
                                in app: XCUIApplication) {
        let filter = app.buttons[control]
        tap(filter, labelled: "the filter control ('\(control)')",
            revealing: app.buttons[collection], called: "the '\(collection)' row")
        app.buttons[collection].tap()
        note("ticked '\(collection)'")
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
