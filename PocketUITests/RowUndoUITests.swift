import XCTest

/// Regression guard for the **Undo doesn't restore the row until you leave and come back** bug
/// (Slice 3, found on device 2026-07-29).
///
/// Two causes compounded, and neither was reachable from a unit test — both were *wiring*:
/// 1. `.pocketRowUndoHost()` owned the coordinator itself, but a modifier applied inside a view's
///    `body` publishes its environment to that view's **descendants** only. The screen's own
///    `@Environment(\.rowDeletion)` resolved from its parent — the default no-op seam — so every
///    pending-row filter silently did nothing. The coordinator is now owned by the screen.
/// 2. The trailing swipe used `Button(role: .destructive)`, which plays SwiftUI's own row-removal
///    animation on tap regardless of the data. That made the row *look* deleted, so cause 1 was
///    invisible until Undo failed to bring it back. The swipe button is now a plain tinted button.
///
/// The observable contract this pins: after Undo, the row is back **on the same screen**, with no
/// navigation in between.
///
/// **It raced its own subject, and turned `main` red on 2026-07-29** (CI run 30441349304, the
/// post-merge build of PR #188 — nothing in that PR touched row actions). The undo toast lives for
/// `RowDeletionCoordinator.window`, counted from the Delete tap; this test then waited up to five
/// seconds for the row to vanish *before* looking for Undo, so on a slow runner the button it
/// finally found had already expired: `waitForExistence` passed, `tap()` reported "No matches
/// found". Two changes, because either alone only narrows the gap:
/// - the wait order is inverted here — grab the thing on a clock first;
/// - `RowDeletionCoordinator.window` is stretched under `-uiTesting`, since the four-second figure
///   is a *product* decision this test was never asserting.
final class RowUndoUITests: UITestCase {

    @MainActor
    func testUndoRestoresADeletedRowWithoutLeavingTheScreen() throws {
        let app = launchApp()

        try openExercisesLibrary(in: app)

        // "Alternate Picking" is in `PracticePresets.firstRunSlugs`, so a clean install has it, and it
        // collides with no section header (unlike "Legato", which is also a template section).
        let drill = app.cells.containing(.staticText, identifier: "Alternate Picking").firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout), "no seeded exercise to delete")
        scrollIntoView(drill, in: app)

        drill.swipeLeft()
        let deleteButton = app.buttons["Delete Alternate Picking"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: Self.uiTimeout), "trailing swipe offered no Delete")
        deleteButton.tap()

        // Reach for **Undo first**. The toast and the row's disappearance come from one state
        // change, so both are true at the same instant — but only the toast is on a clock, and any
        // wait placed in front of it is spent out of the undo window (see the flake note above).
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: Self.uiTimeout), "no Undo toast after deleting")

        // The row leaves because the *filter* hid it — nothing is deleted yet.
        XCTAssertTrue(waitForDisappearance(of: drill), "the deleted row stayed on screen")

        undo.tap()

        // The whole point: back immediately, on this screen, with no navigation.
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout),
                      "Undo did not restore the row in place (host/environment scoping regression)")
    }

    /// The **Journal** feed's undo, which the library test above does not reach: a different screen,
    /// a different coordinator, and — since 2026-08-06 — a different *gesture*. Delete here is a
    /// press-and-hold, never a swipe, because a reflection has no source to rebuild it from the way
    /// an exercise does. That makes this the only test that would catch the hold menu being wired to
    /// nothing.
    ///
    /// A clean install's Journal is empty, so the test **writes its own note** through the app's real
    /// capture path rather than a seeded fixture — no test-only code in the app, and the write half of
    /// the feature gets walked on the way in.
    ///
    /// A take would have been the more valuable subject — its delete removes an audio file — but a
    /// take cannot be created in the simulator at all: it needs a real microphone. The Takes sheet
    /// shares this screen's coordinator, gesture and deferral, so this covers the pattern; the audio
    /// path itself stays a device check.
    @MainActor
    func testUndoRestoresADeletedJournalNote() throws {
        let app = launchApp()
        // Unique per run. The simulator keeps the app's store between test runs, so a fixed string
        // accumulates a row per run on a dev machine — and then `firstMatch` finds *last* run's copy
        // still on screen after this run's is deleted, failing on a bug that isn't there.
        let noteText = "Undo test note \(UUID().uuidString.prefix(6))"
        try writeAJournalNote(noteText, in: app)
        try openJournal(in: app)

        let note = app.cells.containing(.staticText, identifier: noteText).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: Self.uiTimeout), "the note just written isn't on the feed")

        note.press(forDuration: 1.2)
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: Self.uiTimeout), "the hold menu offered no Delete")
        deleteButton.tap()

        // Undo first — it is the thing on a clock. See the flake note on the test above.
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: Self.uiTimeout), "no Undo toast after deleting a note")
        XCTAssertTrue(waitForDisappearance(of: note), "the deleted note stayed on screen")

        undo.tap()
        XCTAssertTrue(note.waitForExistence(timeout: Self.uiTimeout), "Undo did not restore the journal note")
    }

    // MARK: - Helpers

    /// Write one note against a seeded drill, through the app's own capture path: Exercises → the
    /// drill's run screen → the nav-bar quick-note button → Save. Leaves the app back on Home.
    ///
    /// Deliberately the **toolbar** button (ADR 0142) rather than the review bar's Journal pill: the
    /// bar is the last thing in a long `ScrollView`, so on a fresh run screen it isn't in the
    /// accessibility tree at all until you scroll it in. A toolbar item always is.
    @MainActor
    private func writeAJournalNote(_ text: String, in app: XCUIApplication) throws {
        try openExercisesLibrary(in: app)

        let drill = app.cells.containing(.staticText, identifier: "Alternate Picking").firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout), "no seeded exercise to write a note against")
        scrollIntoView(drill, in: app)
        drill.tap()

        let quickNote = app.buttons["Write a quick journal note"]
        XCTAssertTrue(quickNote.waitForExistence(timeout: Self.uiTimeout), "no quick-note button on the run screen")
        quickNote.tap()

        // `TextField(axis: .vertical)` surfaces as a text *view* on some runtimes and a text field on
        // others, so accept either rather than pinning the test to one of them.
        let field = composerField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout), "the quick-note sheet has no field")
        field.tap()
        field.typeText(text)

        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: Self.uiTimeout), "no Save button on the quick-note sheet")
        save.tap()

        try returnHome(in: app)
    }

    @MainActor
    private func composerField(in app: XCUIApplication) -> XCUIElement {
        let placeholder = "What just happened?"
        let asField = app.textFields[placeholder]
        return asField.waitForExistence(timeout: Self.uiTimeout) ? asField : app.textViews[placeholder]
    }

    /// Pop back to Home. The run screen is three levels deep (Home → Practice hub → Exercises
    /// library → run), so this walks the back button until Home's own first card shows up rather
    /// than counting taps.
    @MainActor
    private func returnHome(in app: XCUIApplication) throws {
        let homeMarker = app.buttons["Practice, your exercises and training runs"]
        var backs = 0
        while !homeMarker.exists && backs < 5 {
            let back = app.navigationBars.buttons.firstMatch
            guard back.waitForExistence(timeout: Self.uiTimeout) else { break }
            back.tap()
            backs += 1
        }
        XCTAssertTrue(homeMarker.waitForExistence(timeout: Self.uiTimeout), "never got back to Home")
    }

    /// Home → Journal.
    @MainActor
    private func openJournal(in app: XCUIApplication) throws {
        let journalCard = app.buttons["Journal, your notes and practice takes"]
        XCTAssertTrue(journalCard.waitForExistence(timeout: Self.uiTimeout), "Journal card missing")
        XCTAssertTrue(scrollIntoView(journalCard, in: app), "Journal card not reachable by scrolling")
        journalCard.tap()
    }

    /// Home → Practice → Exercises.
    @MainActor
    private func openExercisesLibrary(in app: XCUIApplication) throws {
        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: Self.uiTimeout), "Practice card missing")
        XCTAssertTrue(scrollIntoView(practiceCard, in: app), "Practice card not reachable by scrolling")
        practiceCard.tap()

        let exercisesRow = app.cells.containing(.staticText, identifier: "Exercises").firstMatch
        XCTAssertTrue(exercisesRow.waitForExistence(timeout: Self.uiTimeout), "Exercises library row missing")
        exercisesRow.tap()
    }
}
