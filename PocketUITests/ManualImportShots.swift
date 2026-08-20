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
    /// `app.screenshot()` photographs the application under test, so a picker drawn by another
    /// process comes back as a clean picture of Home with nothing over it — and app-scoped queries
    /// cannot see it either, so there is nothing to assert on and nothing in the frame. Both halves
    /// are solved separately: the gate below reaches across to the picker's own process, and
    /// `capture(wholeDisplay: true)` takes the display rather than the app.
    ///
    /// **The first identifier tried here could never have resolved.** It was
    /// `com.apple.DocumentManagerUICore`, which on the iOS 26.5 runtime is a *PrivateFramework*, not
    /// an application — so `XCUIApplication(bundleIdentifier:)` was being handed the name of a
    /// dylib. The picker is hosted by that framework's plug-in, whose `CFBundleIdentifier` is
    /// `com.apple.DocumentManagerUICore.Service`:
    ///
    ///     RuntimeRoot/System/Library/PrivateFrameworks/DocumentManagerUICore.framework
    ///         /PlugIns/com.apple.DocumentManager.Service.appex
    ///
    /// Hence a *list*, not a name. These are Apple's to rename at any release and this test cannot
    /// tell a renamed host from an absent picker, so it tries each and reports all of them on
    /// failure — the next OS bump should cost a reading of the log, not another guess. That dump
    /// earned its keep on the first run: it showed `com.apple.DocumentManagerUICore.Service` present
    /// with `Cancel` in it, which turned "the bundle id is wrong" into "the sweep was too impatient"
    /// without a second guess or a second run.
    private static let pickerBundleIDs = [
        "com.apple.DocumentManagerUICore.Service",   // the picker's remote-view extension
        "com.apple.CloudDocsUI.DocumentPicker",      // iCloud Drive's own picker extension
        "com.apple.DocumentsApp"                     // the Files app, if it fronts the picker
    ]

    /// The first candidate process showing the picker, or `nil` once the deadline passes.
    ///
    /// **Swept repeatedly against one deadline, rather than each candidate waited out in turn.**
    /// The first shape of this gave every candidate its own generous timeout, one after another, and
    /// failed on a cold device *while the picker was opening*: three sequential waits expired, and
    /// the tree dumped by the failure — taken after all of them — showed the picker present, with
    /// `Cancel` exactly where this was looking for it. A per-candidate timeout long enough to cover
    /// a slow open multiplies by the number of candidates, and most of that wait is spent on
    /// processes that were never going to answer.
    ///
    /// So each probe is brief and the *sweep* is what repeats. A wrong bundle id still fails fast
    /// and stays failing; a slow open is caught by a later lap.
    @MainActor
    private func resolvedPicker() -> XCUIApplication? {
        let deadline = Date().addingTimeInterval(Self.shootTimeout)
        repeat {
            for id in Self.pickerBundleIDs {
                let candidate = XCUIApplication(bundleIdentifier: id)
                if candidate.buttons["Cancel"].waitForExistence(timeout: Self.pickerProbeTimeout) {
                    note("the document picker is hosted by '\(id)'")
                    return candidate
                }
            }
        } while Date() < deadline
        return nil
    }

    /// Per-probe patience. Deliberately short — the sweep above is what provides the patience, and a
    /// long value here is paid once per candidate per lap.
    private static var pickerProbeTimeout: TimeInterval { 2 }

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

        guard resolvedPicker() != nil else {
            let dump = Self.pickerBundleIDs
                .map { "── \($0) ──\n\(XCUIApplication(bundleIdentifier: $0).debugDescription)" }
                .joined(separator: "\n")
            XCTFail("""
                the document picker never appeared in any of the processes known to host it. It is \
                a separate process, so this gate is a guess about somebody else's bundle id — here \
                is what each candidate actually offers. If one of them is plainly the picker under \
                a new name, add it to `pickerBundleIDs`; if they are all empty, the picker did not \
                open at all and the tap is what to look at.
                \(dump)
                \(stepLog)
                """)
            return
        }

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
