import XCTest

/// The manual's **Practice-side library** figures (ADR 0165, Phase 5) — the hub, the two libraries
/// that hang off it, the long-term goal list, and the routine detail screen's history.
///
/// Every capture here is a navigate-and-shoot: the screens are read-only lists, and nothing in this
/// class authors anything. That is deliberate and it is a constraint of the shoot rather than a
/// preference. `shoot-manual.sh` erases the simulator **once**, before the whole run, and both seeds
/// refuse to run twice — so a test that creates a goal or saves a routine changes the world for
/// every test that runs after it, in an order nothing here controls. Figures whose state has to be
/// *built* (a goal added, three blocks in an editor) belong in one test that shoots the before and
/// the after in sequence, not spread across two.
///
/// **What had to be seeded before any of this could be shot.** `reference/long-term-goals` asks for
/// "two goals ranked" and `routines/library` for "several routines saved"; the store held none and
/// one respectively, so both figures would have come back as clean photographs of a state the page
/// does not describe. `PracticeHistorySeed+Authored` writes them — see its note on why a screen and
/// its seed ship together.
final class ManualPracticeShots: ManualShotCase {

    /// `reference/practice-hub` — five rows in two sections, each carrying a count.
    ///
    /// The required label is the **Long-term goals** row with its count, which is doing two jobs: it
    /// proves the goal seed landed, and it is the row most recently added to this screen (ADR 0171),
    /// so it is the one a stale build would be missing.
    @MainActor
    func testPracticeHub() {
        let app = launchForShoot()
        openPractice(in: app)
        capture(app, slug: "reference/practice-hub",
                assertingOnScreen: "Practice",
                orBeginningWith: ["Long-term goals, 2"])
    }

    /// `reference/exercises-library` · `exercises/library` — drills grouped into collapsible
    /// template sections.
    ///
    /// Asserted on a **section header**, not a drill: the sections are what the figure is of, the
    /// rows inside them are ordinary, and a header is at the top of the screen where a `role: screen`
    /// capture can actually see it. `Picking` holds the seeded Alternate Picking drill.
    ///
    /// **The two markers are one screen in one state** — "the seeded six present" and "several
    /// templates present" — so they share this frame rather than being shot twice. That is worth
    /// more than tidiness here. `exercises/library` was listed for a hand shoot with an ordering rule
    /// beside it: shoot it *before* authoring the freeform drill, or a seventh row appears in one
    /// figure of this screen and not the other. Serving both markers from a pass that never authors
    /// anything retires the rule instead of restating it.
    @MainActor
    func testExercisesLibrary() {
        let app = launchForShoot()
        openPractice(in: app)
        tapRow(labelStartingWith: "Exercises,", in: app,
               arrivingAt: app.navigationBars["Exercises"], called: "the Exercises library")
        capture(app, slug: "reference/exercises-library",
                assertingOnScreen: "Exercises",
                orBeginningWith: ["Picking"],
                alsoServing: ["exercises/library"])
    }

    /// `routines/library` · `reference/routines-library` — the list, with one routine carrying a
    /// history line and two not.
    ///
    /// **Both halves are asserted, and that is the whole point of the figure.** `Practised` proves
    /// the log-derived second line renders at all; `Evening technique` proves there is a routine
    /// beside it *without* one. A capture that checked only the first would pass on a one-row library
    /// and photograph a list that cannot show the line is conditional.
    ///
    /// The count itself is deliberately not pinned. It is derived from `routineDayOffsets` through
    /// `PracticeLog.sittings`, and an assertion naming a number here would have to be re-derived
    /// every time those offsets move — the number is what the audit of the image is for.
    @MainActor
    func testRoutinesLibrary() {
        let app = launchForShoot()
        openPractice(in: app)
        openRoutines(in: app)
        capture(app, slug: "routines/library",
                assertingOnScreen: "Routines",
                orBeginningWith: ["Practised", "Evening technique"],
                alsoServing: ["reference/routines-library"])
    }

    /// `routines/history` — the length-and-history section of a saved routine (ADR 0173).
    ///
    /// A `role: detail` crop, so the section has to be **in the frame**, not merely on the screen:
    /// it sits below the block list, and Morning Routine is six blocks long. `scrollIntoFrame` is
    /// aimed at the *last* row of the section — the count line — because stopping at the first would
    /// leave the rest of it under the fold, which is how the references figure failed twice.
    ///
    /// Asserting `Estimated length` matters beyond composition: before ADR 0173 that row was gated
    /// on the routine *not* being in the store, so on this screen it is the half of the section that
    /// a regression would silently drop while `Last practised` carried on rendering.
    @MainActor
    func testRoutineHistory() {
        let app = launchForShoot()
        openPractice(in: app)
        openRoutines(in: app)
        tapRow(labelStartingWith: "Morning Routine", in: app,
               arrivingAt: app.navigationBars["Morning Routine"],
               called: "the Morning Routine detail screen")

        scrollIntoFrame(element(in: app, labelStartingWith: "Practised"),
                        called: "the practice count", in: app)
        capture(app, slug: "routines/history",
                assertingOnScreen: "Morning Routine",
                alsoRequiring: ["Estimated length", "Last practised"],
                orBeginningWith: ["Practised"])
    }

    /// `reference/long-term-goals` — the ranked list, each row with its skill count.
    ///
    /// The second goal is the one asserted. It is the Path-B shape (ADR 0171) — the one carrying a
    /// target song after its skill count — so a seed that wrote only the simpler shape, or a build
    /// where the song link stopped resolving, fails here rather than photographing a list that looks
    /// complete.
    @MainActor
    func testLongTermGoals() {
        let app = launchForShoot()
        openPractice(in: app)
        tapRow(labelStartingWith: "Long-term goals,", in: app,
               arrivingAt: app.navigationBars["Long-term goals"], called: "the long-term goal list")
        capture(app, slug: "reference/long-term-goals",
                assertingOnScreen: "Long-term goals",
                orBeginningWith: ["Play Slow Bend end to end"])
    }

    /// `reference/loops-library` — the Loops library with nothing measured in it yet.
    ///
    /// **This figure was on the bare-device list and does not belong there.** It was grouped with
    /// `songs/empty-library` as one of two shots needing a device with nothing on it, and the source
    /// does not bear that out: `LoopLibraryView.emptyStateMessage` has *two* empty states, and which
    /// one it draws turns on `hasAnyLoops`, not on whether any are measured.
    ///
    /// A bare device has no songs and therefore no loops, so it draws *"No loops yet. Open a song,
    /// draw a loop on the waveform"* — while the marker's alt text promises the other one, the copy
    /// that explains loops appear **once a command tempo is set**. That sentence only exists when
    /// there are unmeasured loops for it to be about, which is exactly the seeded device: six songs,
    /// one loop each, none measured. The Practice hub says as much on the way past — `Loops, 0`.
    ///
    /// So the figure is shot here, on the seeded device, and the bare pass is left with the one shot
    /// that genuinely needs it. Asserted on the copy rather than on emptiness, because "the list is
    /// empty" is true of both states and this figure is about which of them is showing.
    @MainActor
    func testLoopsLibrary() {
        let app = launchForShoot()
        openPractice(in: app)
        tapRow(labelStartingWith: "Loops,", in: app,
               arrivingAt: app.navigationBars["Loops"], called: "the Loops library")
        capture(app, slug: "reference/loops-library",
                assertingOnScreen: "Loops",
                orBeginningWith: ["No measured loops yet."])
    }

    // MARK: - Navigation

    /// Home ▸ `Practice`.
    ///
    /// The card's accessibility label is the full "Practice, your exercises and training runs" — the
    /// arrival gate is the hub's **navigation bar**, because Home's card says the word "Practice"
    /// too and a gate the starting screen already satisfies is not a gate (`tapHomeCard`).
    @MainActor
    private func openPractice(in app: XCUIApplication) {
        tapHomeCard("Practice, your exercises and training runs", in: app,
                    arrivingAt: app.navigationBars["Practice"])
    }

    /// Practice ▸ `Routines`.
    ///
    /// Matched with the trailing comma — the row's label is `Routines, 3`, and the count moves with
    /// the seed. ⚠️ Not reusable from *inside* the Routines stack: one screen down, the back button
    /// carries the previous screen's title, and a loose prefix there pops the stack and photographs
    /// the wrong screen green all the way.
    @MainActor
    private func openRoutines(in app: XCUIApplication) {
        tapRow(labelStartingWith: "Routines,", in: app,
               arrivingAt: app.navigationBars["Routines"], called: "the Routines library")
    }
}
