import XCTest

/// The two library figures that **change the store** (ADR 0165, Phase 5) — the system file picker
/// over Home, and the undo toast after a row is deleted.
///
/// Its own pass, on its own erased device, for the reason every authoring pass has one: a delete
/// that is not undone in time removes a song from the library every other library figure is a
/// picture of, and an import adds one. Neither is a risk worth carrying on a shared device to save
/// two minutes of boot.
final class ManualImportShots: ManualShotCase {

    /// The system document picker's process. **Not the app**, which is the whole difficulty.
    ///
    /// `app.screenshot()` photographs the application under test, so a picker drawn by
    /// `com.apple.DocumentManagerUICore` comes back as a clean picture of Home with nothing over it —
    /// and app-scoped queries cannot see it either, so there is nothing to assert on and nothing in
    /// the frame. Both halves are solved separately: the gate below reaches across to the picker's
    /// own process, and `capture(wholeDisplay: true)` takes the display rather than the app.
    private var documentPicker: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.DocumentManagerUICore")
    }

    /// `getting-started/import-picker` — the file picker open over Home.
    ///
    /// Gated on the picker's **Cancel**, resolved in the picker's process. If that ever stops
    /// resolving, the failure message carries the picker's own accessibility tree — which is the one
    /// thing that makes a cross-process gate debuggable, and is not otherwise recoverable from a
    /// screenshot of a system UI whose internals are Apple's to change.
    @MainActor
    func testImportPicker() {
        let app = launchForShoot()

        let add = app.buttons["Add a song"]
        XCTAssertTrue(add.waitForExistence(timeout: Self.shootTimeout),
                      "no 'Add a song' control on Home.\n\(stepLog)")
        awaitHittable(add)
        add.tap()
        note("tapped 'Add a song'")

        let cancel = documentPicker.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: Self.shootTimeout), """
            the document picker never appeared. It is a separate process, so this gate is a guess \
            about somebody else's accessibility text — here is what that process actually offers:
            \(documentPicker.debugDescription)
            \(stepLog)
            """)
        note("the document picker is up")

        capture(app, slug: "getting-started/import-picker",
                assertingOnScreen: "Red Moon",
                wholeDisplay: true)
    }

    /// `gestures/undo-toast` — the toast a deleted row leaves behind, and its Undo.
    ///
    /// **`-uiTesting` is what makes this shootable at all.** `RowDeletionCoordinator` stretches the
    /// undo window from 4 seconds to 120 under it, so the capture is not racing the toast out of
    /// existence — which on a driven run is the difference between a figure and a coin toss.
    ///
    /// Undo is tapped afterwards, so the pass leaves the library with six songs. That is belt and
    /// braces on top of the pass being its own device: the row is only really deleted when the window
    /// closes, and this finishes long before it does.
    ///
    /// **Binta**, the first row, so the swipe needs no scroll — and `Delete Binta`, because the swipe
    /// action names the row it will delete rather than saying `Delete`.
    @MainActor
    func testUndoToast() {
        let app = launchForShoot()

        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Song library card on Home.\n\(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Library"])

        let row = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Binta,")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.shootTimeout),
                      "no Binta row to swipe.\n\(stepLog)")
        awaitHittable(row)
        row.swipeLeft()
        note("swiped the Binta row left")

        let delete = app.buttons["Delete Binta"]
        tap(delete, labelled: "Delete Binta",
            revealing: app.buttons["Undo"], called: "the undo toast")

        capture(app, slug: "gestures/undo-toast",
                assertingOnScreen: "Library",
                alsoRequiring: ["Undo"])

        // Put it back. Asserted rather than fired and forgotten — an Undo that did not land leaves
        // this pass's device a song short, and the next figure shot from it would be of a library
        // that quietly lost one.
        app.buttons["Undo"].tap()
        note("tapped Undo")
        XCTAssertTrue(row.waitForExistence(timeout: Self.shootTimeout), """
            Undo did not bring the Binta row back, so this device is now a song short.
            \(stepLog)
            """)
    }
}
