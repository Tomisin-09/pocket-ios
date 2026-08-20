import XCTest

/// Reaching things: the queries every shot class uses to find a control, and the scroll that puts
/// one **in the picture** rather than merely within tapping distance.
///
/// Split out of `ManualShotCase.swift` to keep that file under the 400-line cap. One type, two
/// files — so everything here is `internal`, not `private`; Swift has no cross-file-private.
extension ManualShotCase {

    /// Swipe until `element` is **inside the window**, not merely hittable.
    ///
    /// The distinction is the one this whole file is built around, and `isHittable` is the wrong
    /// side of it: it answers *could a tap reach this*, which a row just past the fold can satisfy,
    /// while `capture()` asks *is this in the picture*. A scroll helper gated on hittability
    /// therefore returns happy from a screen where the subject is not visible, and the failure
    /// surfaces one step later as `NOT IN FRAME` — a true message about the wrong cause. Measured on
    /// `references/section`, whose ten navigation steps all passed before it.
    ///
    /// Swipes slowly, for the reason `scrollToCard` does: a fast swipe carries the subject past the
    /// viewport and then reports it missing.
    ///
    /// - Parameter element: resolved by the **caller**, from a narrow query (`app.buttons[…]`,
    ///   `app.staticTexts[…]`). Deliberately not a label matched against
    ///   `descendants(matching: .any)`: that query walks the whole tree, and running it up to eleven
    ///   times in this loop timed out the UI query outright on a detail sheet (280s, measured
    ///   2026-08-17). `capture()` can afford it once; a scroll loop cannot.
    /// - Parameter name: what to call it in the step log.
    ///
    /// **Aim it at the *last* thing the figure needs, not the first.** Scrolling until a section's
    /// header is in frame stops with the rest of the section below the fold — which is how this
    /// failed a second time, with the header visible and `Add a link` out of shot.
    @MainActor
    func scrollIntoFrame(_ element: XCUIElement,
                         called name: String,
                         in app: XCUIApplication,
                         maxSwipes: Int = 10,
                         file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: Self.shootTimeout)
        let window = app.windows.firstMatch.frame

        for pass in 0...maxSwipes {
            let frame = element.exists ? element.frame : .zero
            if !frame.isEmpty && window.contains(frame) {
                note("'\(name)' is in frame" + (pass > 0 ? " after \(pass) swipe(s)" : ""))
                return
            }
            app.swipeUp(velocity: .slow)
        }

        // Which of the two failures this is decides where to look, so it is worked out here rather
        // than left to whoever reads the log: in the tree means scrolling, absent means wrong screen.
        let verdict = element.exists
            ? "It is in the tree, so this is a scrolling problem, not a missing element."
            : "It is not in the tree at all, so this is the wrong screen — or the wrong name for it."
        XCTFail("""
            never brought '\(name)' into the frame in \(maxSwipes) slow swipes. \(verdict)
            \(diagnosis(for: name, in: app))
            \(stepLog)
            """, file: file, line: line)
    }

    /// Swipe blind until a row **enters the tree at all**, then return it.
    ///
    /// `scrollIntoFrame` and `scrollIntoView` both watch an element while they scroll, so both need
    /// one to exist before they can start. Below the fold in a SwiftUI `List` there is nothing to
    /// watch: the row has not been built, so it is not merely off-screen, it is absent — `exists` is
    /// false and `waitForExistence` times out against a screen the row is plainly on.
    ///
    /// Measured, not feared. The seeded library sorts by title and holds six songs; **Slow Bend** is
    /// the fifth, and every song-player figure in the manual is shot on it. The first walk of that
    /// screen reported `MISS 'Slow Bend' — not in the tree` and carried on photographing the library,
    /// which is exactly the wrong-subject failure this harness exists to catch, arriving through a
    /// helper that could not start.
    ///
    /// So this swipes first and queries after, which is the only order that works, and hands back to
    /// `scrollIntoFrame` once there is something to watch.
    ///
    /// - Parameter prefix: matched against `Button` labels only. A row carries its metadata after
    ///   its title (`Slow Bend, Jack Trader, 1 loop, …`), so a prefix is the right shape — but never
    ///   aim one at text the **back button** shares, which inside a pushed screen is the previous
    ///   screen's title.
    @MainActor
    @discardableResult
    func revealRow(labelStartingWith prefix: String,
                   in app: XCUIApplication,
                   maxSwipes: Int = 10,
                   file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        for pass in 0...maxSwipes {
            if row.exists {
                note("revealed row '\(prefix)'" + (pass > 0 ? " after \(pass) swipe(s)" : ""))
                return row
            }
            app.swipeUp(velocity: .slow)
        }
        XCTFail("""
            no row whose label begins '\(prefix)' after \(maxSwipes) slow swipes — it never entered \
            the tree, so either this is the wrong screen or the list does not hold it.
            \(stepLog)
            """, file: file, line: line)
        return row
    }

    /// Is this element in the **photograph** — not merely in the accessibility tree?
    ///
    /// `exists` was the original check here, and it is not the same question. A scrolled-away section
    /// stays in the tree at its true offset, so an element metres above the top of the screen reports
    /// `exists == true` for as long as its scroll view holds it. `journal/progress` was shot that way
    /// and passed: the run asserted `THIS WEEK`, the tree agreed, and the image that came back showed
    /// This month and All-time with This week nowhere in it. A green run, a clean picture, the wrong
    /// figure — which is the one failure this whole file is written against, arriving through the
    /// assertion meant to prevent it.
    ///
    /// Full containment, not intersection: a section sliced by the edge of the frame is not a section
    /// the reader can see, and half a bar chart in a manual is worse than a missing one.
    ///
    /// Occlusion is a separate problem this cannot see — the navigation bar is translucent and draws
    /// over content that is legitimately inside the window. That is a matter of how a figure is
    /// composed rather than what is asserted about it, and is handled by not scrolling a header under
    /// the bar in the first place.
    /// Takes a **query**, not an element, and asks whether *any* match is in the picture.
    ///
    /// Both halves of that matter. `element.frame` throws outright when its query matches more than
    /// one thing — `Start`, `Done` and `Less` each match a button and the label inside it — and
    /// `exists` does not, so the first version of this sailed through the existence gate and then
    /// failed five tests with `Multiple matching elements found`. Taking `.firstMatch` would have
    /// silenced that while introducing something worse: a screen showing two `More`s would be judged
    /// on whichever the query reached first, which may be the one scrolled off the top.
    @MainActor
    func isInFrame(_ query: XCUIElementQuery, of app: XCUIApplication) -> Bool {
        let window = app.windows.firstMatch.frame
        return query.allElementsBoundByAccessibilityElement.contains { candidate in
            let frame = candidate.frame
            return !frame.isEmpty && window.contains(frame)
        }
    }

    // MARK: - Queries

    /// The first element of any type whose label begins with `prefix`.
    ///
    /// Rows built as `NavigationLink`s wrapping a `LabeledContent` surface as a button, a cell or an
    /// other-element depending on what is inside them, and the trait is not worth predicting — the
    /// existing `SettingsHubUITests` and `ToolkitUITests` both learned that. Prefix rather than exact
    /// because a row's label carries its current value after the title.
    ///
    /// ⚠️ Never aim a prefix at content the **back button** could also match: inside a pushed screen
    /// that control carries the *previous* screen's title, so a loose match pops the stack and every
    /// later capture is quietly of the wrong screen — green the whole way.
    @MainActor
    func element(in app: XCUIApplication, labelStartingWith prefix: String) -> XCUIElement {
        elements(in: app, labelStartingWith: prefix).firstMatch
    }

    /// The same query, unresolved — for callers that need to weigh every match rather than the first.
    @MainActor
    func elements(in app: XCUIApplication, labelStartingWith prefix: String) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
    }

    /// Tap one of Home's nav cards, which live in titled sections below the fold (ADR 0102).
    ///
    /// **Not `scrollIntoView`.** That helper swipes at the default velocity, which on Home's short
    /// scroll view moves more than a card's height per swipe, and it decides where it is by comparing
    /// frames between swipes. Two things follow, and this shoot hit both in one run: a single swipe
    /// can carry the card clean past the viewport, so the next `exists` check fails and the helper
    /// gives up on a card that is right there; and a card can pass `isHittable` and then be somewhere
    /// else by the time the tap is synthesised, because the scroll is still decelerating — which
    /// produces a tap on whatever slid into that spot, a green navigation step, and a figure of the
    /// wrong screen.
    ///
    /// So: slow swipes, and the hittable check re-read immediately before the tap on each pass rather
    /// than once at the end. Both failures were intermittent, which is the reason to fix the movement
    /// rather than retry the run — at ninety-six figures a shoot that misses two at random is a shoot
    /// whose output has to be audited twice.
    /// - Parameter arrivingAt: an element that exists on the destination and **not on Home**. The tap
    ///   is retried until this appears, because a tap on the coldest first launch can be accepted and
    ///   then swallowed, leaving the app on Home with the run none the wiser.
    ///
    ///   Choosing it needs care. The first version of this gate waited for `staticTexts["Metronome"]`
    ///   after tapping the Metronome card — and Home's card is *titled* "Metronome", so the assertion
    ///   was true before the tap and could never fail. It duly passed while the app sat on Home, and
    ///   the run failed three steps later with "no + stepper on the metronome": a true sentence about
    ///   a screen we were never on. Pick something the destination owns — a toolbar control, a
    ///   navigation bar — never a word Home also says.
    @MainActor
    func tapHomeCard(_ label: String,
                     in app: XCUIApplication,
                     arrivingAt arrival: XCUIElement,
                     maxSwipes: Int = 8,
                     attempts: Int = 3,
                     file: StaticString = #filePath, line: UInt = #line) {
        let card = app.buttons[label]
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no '\(label)' card on Home.\n\(stepLog)", file: file, line: line)

        tap(card, labelled: label, revealing: arrival, called: "the destination",
            attempts: attempts, file: file, line: line) {
            guard self.scrollToCard(card, in: app, maxSwipes: maxSwipes) else {
                XCTFail("""
                    '\(label)' never became tappable on Home within \(maxSwipes) slow swipes — it \
                    exists in the tree, so this is a scrolling problem, not a missing card.
                    \(self.stepLog)
                    """, file: file, line: line)
                return false
            }
            return true
        }
    }

    /// Tap a control and wait for what it opens, re-tapping only while the control is still there.
    ///
    /// The shoot's second recurring failure, after the swallowed Home-card tap, and the same shape:
    /// the ⋯ menu on the Journal was found, tapped, the event was synthesised — and the menu did not
    /// open. Thirty seconds of `Checking existence of "Progress" Button` later the run failed, from a
    /// screen where one more tap would have worked.
    ///
    /// **Why a retry here is not the retry ADR 0146 argues against.** That one re-runs a failing test
    /// and takes the second answer, which converts a real defect into a slower green. This one is
    /// gated on evidence that the first tap did nothing: `control.isHittable` is false the moment a
    /// menu's scrim or a pushed screen covers it, so a re-tap only ever happens from a screen that
    /// visibly did not change. If something *did* open and it was the wrong thing, this fails rather
    /// than tapping blind — because a shoot that carries on from an unknown screen is exactly how a
    /// clean photograph of the wrong subject gets made. Every attempt is written to the step log, so
    /// a figure that needed three taps is visible afterwards rather than smoothed away.
    ///
    /// ⚠️ **Never aim this at a toggle.** The retry is sound only for a control that *goes away* when
    /// it works — a row that pushes a screen, a button that opens a sheet, anything that covers or
    /// replaces itself. A disclosure header stays exactly where it is when it works, so the "did
    /// anything happen?" test is satisfied on every attempt and the retry fires every time — and each
    /// retry reverses the last one. `exercises/practice-settings` was written this way and reported
    /// *tapped 3× and the expanded panel never appeared* about a panel the first tap had opened
    /// correctly: expand, collapse, expand, with the two probes in between looking at the wrong
    /// state. For a toggle, tap once by hand and assert what it revealed — and if the revealed thing
    /// is below the fold, reach it with `scrollIntoFrame`, which can tell "not scrolled to" from
    /// "not there" and says which it was.
    ///
    /// - Parameter revealing: an element the destination owns and the current screen does **not**.
    ///   A gate the starting screen can already satisfy is not a gate — see `tapHomeCard`.
    /// - Parameter prepare: run before each tap; return `false` to abandon (it has already failed).
    @MainActor
    func tap(_ control: XCUIElement,
             labelled label: String,
             revealing revealed: XCUIElement,
             called revealedName: String,
             attempts: Int = 3,
             file: StaticString = #filePath, line: UInt = #line,
             beforeEachTap prepare: () -> Bool = { true }) {
        for attempt in 1...attempts {
            guard prepare() else { return }
            guard awaitHittable(control) else {
                XCTFail("""
                    '\(label)' is in the tree but never became hittable, so the tap could not be \
                    synthesised at all. This is a race, not a swallowed tap.
                    \(stepLog)
                    """, file: file, line: line)
                return
            }

            control.tap()
            note("tapped '\(label)'" + (attempt > 1 ? " (attempt \(attempt))" : ""))

            // Only the last attempt is given the full timeout: a swallowed tap shows as nothing
            // happening, not as slowness, so probing briefly first costs a failing shoot nothing.
            let patience = attempt == attempts ? Self.shootTimeout : Self.tapProbeTimeout
            if revealed.waitForExistence(timeout: patience) {
                note("\(revealedName) appeared after '\(label)'")
                return
            }

            guard control.exists && control.isHittable else {
                XCTFail("""
                    tapped '\(label)' and it is no longer reachable, but \(revealedName) never \
                    appeared — so something opened and it is not what this shot needs, and any \
                    capture from here would be of the wrong thing.
                    \(stepLog)
                    """, file: file, line: line)
                return
            }
            note("tap \(attempt) changed nothing — '\(label)' is still there, retrying")
        }

        XCTFail("""
            tapped '\(label)' \(attempts)× and \(revealedName) never appeared.
            \(stepLog)
            """, file: file, line: line)
    }

    /// **Hold** a control and wait for what it opens — `tap(_:revealing:)` for a long press.
    ///
    /// Four figures are context menus a player reaches by holding (`gestures/row-hold-menu`,
    /// `reference/library-row-menu`, `routines/rest-insert`, `looping/multi-select`), and a hold is
    /// lost the same way a tap is: the gesture is synthesised, accepted, and nothing opens. It is
    /// worse here, because a lost hold leaves the app on a screen that is *supposed* to be in the
    /// frame — the library is still the library with no menu over it — so the capture that follows is
    /// a clean, plausible, wrong photograph.
    ///
    /// One difference from `tap`, and it is deliberate: a press is retried only while the revealed
    /// item is still absent, and the item is checked **first**. A context menu that did open covers
    /// its own row with a scrim, so pressing again would dismiss it — the retry would undo the thing
    /// it is meant to secure.
    ///
    /// - Parameter revealing: an item the menu owns. Never the row's own label: the menu draws a
    ///   *preview* of the held row, so the row's text is in the tree either way and gating on it
    ///   cannot tell an open menu from a closed one.
    @MainActor
    func hold(_ control: XCUIElement,
              labelled label: String,
              revealing revealed: XCUIElement,
              called revealedName: String,
              duration: TimeInterval = 1.0,
              attempts: Int = 3,
              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.waitForExistence(timeout: Self.shootTimeout),
                      "nothing to hold: '\(label)' is not in the tree.\n\(stepLog)",
                      file: file, line: line)

        for attempt in 1...attempts {
            if revealed.exists {
                note("\(revealedName) is open, not pressing '\(label)' again")
                return
            }
            guard awaitHittable(control) else {
                XCTFail("""
                    '\(label)' is in the tree but never became hittable, so the press could not be \
                    synthesised at all. This is a race, not a swallowed gesture.
                    \(stepLog)
                    """, file: file, line: line)
                return
            }
            control.press(forDuration: duration)
            note("held '\(label)'" + (attempt > 1 ? " (attempt \(attempt))" : ""))

            let patience = attempt == attempts ? Self.shootTimeout : Self.tapProbeTimeout
            if revealed.waitForExistence(timeout: patience) {
                note("\(revealedName) appeared after holding '\(label)'")
                return
            }
            note("hold \(attempt) opened nothing, retrying")
        }

        XCTFail("""
            held '\(label)' \(attempts)× and \(revealedName) never appeared — so the screen is \
            unchanged, and a capture from here would be of the library with no menu on it.
            \(stepLog)
            """, file: file, line: line)
    }

    /// Bring a Home card into reach with slow swipes. Returns whether it ended up hittable.
    @MainActor
    private func scrollToCard(_ card: XCUIElement,
                              in app: XCUIApplication,
                              maxSwipes: Int) -> Bool {
        for _ in 0...maxSwipes {
            if card.exists && card.isHittable { return true }
            app.swipeUp(velocity: .slow)
        }
        return card.exists && card.isHittable
    }

    /// Wait for a row, scroll it into reach, tap it, and log all three — the shape every navigation
    /// step in the shoot takes.
    ///
    /// Returns nothing and fails loudly rather than returning a flag: a shoot that carries on past a
    /// missed tap is precisely how a set of clean images of the wrong screens gets made.
    /// - Parameter arrivingAt: an element the destination owns. Omitting it means the tap is not
    ///   checked at all, which is how `reference/settings-you` came back as a picture of the Settings
    ///   hub: the row was found, the tap was swallowed, and nothing downstream disagreed. Pass it
    ///   wherever the row opens a screen.
    @MainActor
    func tapRow(labelStartingWith prefix: String,
                in app: XCUIApplication,
                arrivingAt arrival: XCUIElement? = nil,
                called arrivalName: String = "the destination",
                file: StaticString = #filePath, line: UInt = #line) {
        let row = element(in: app, labelStartingWith: prefix)
        let found = row.waitForExistence(timeout: Self.shootTimeout)
        note(found ? "found row '\(prefix)'" : "MISSED row '\(prefix)'")
        XCTAssertTrue(found, "no row whose label begins '\(prefix)'.\n\(stepLog)",
                      file: file, line: line)

        XCTAssertTrue(scrollIntoView(row, in: app),
                      "row '\(prefix)' never became tappable.\n\(stepLog)", file: file, line: line)

        guard let arrival else {
            row.tap()
            note("tapped '\(prefix)' (no arrival check)")
            return
        }
        tap(row, labelled: prefix, revealing: arrival, called: arrivalName, file: file, line: line)
    }

}
