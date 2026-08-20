/// The contract between the app and `PocketUITests` — the launch argument XCUITest passes in, and
/// the accessibility identifiers the app puts up for it to wait on (ADR 0146 pass 2).
///
/// **This file is compiled into both targets** (see `project.yml`). A UI test runs in its own
/// process and cannot `@testable import` the app, so the only alternative is the same string
/// literal written out twice — and a renamed identifier that silently stops matching doesn't fail
/// fast, it hangs for the full timeout and then fails with a message about the *wrong* thing. That
/// is the exact failure mode this pass exists to remove, so the constant is shared rather than
/// duplicated.
///
/// It holds strings only: no `CommandLine`, no app types, nothing that would mean something
/// different when compiled into the test bundle.
enum UITestHooks {
    /// Passed by `UITestCase.launchApp()`. Read app-side through `UITestRuntime.isActive`, never by
    /// spelling the literal out at the call site.
    static let launchArgument = "-uiTesting"

    /// `-shotHour <0…23>`: the hour Home's greeting is computed from, for the manual's shoot.
    ///
    /// Home reads the wall clock, and the shoot fakes the status bar to 09:41 — two clocks that
    /// disagree the moment a run crosses a bucket boundary, producing "Late session" under a
    /// morning status bar. That contradiction lives entirely in the pixels, where no assertion
    /// reaches it, so `shoot-manual.sh` used to defend it by refusing to run outside 05:00–11:59.
    ///
    /// A wall-clock gate is the wrong shape for it twice over: it makes a deterministic artefact
    /// depend on when you happened to run it, and it cannot express a figure that needs a
    /// *different* hour — `getting-started/home` asks for an evening greeting and was therefore
    /// unshootable at any time of day. Naming the hour makes both figures reproducible and retires
    /// the gate. Read app-side through `UITestRuntime.shotHour`.
    static let shotHourArgument = "-shotHour"

    /// Marks Home as **finished seeding**, not merely rendered.
    ///
    /// First-launch seeding is a `.task` that paints Home before it completes, so "Home is on
    /// screen" and "the seeded content exists" are different moments — up to seconds apart on a
    /// cold simulator. Every wait that guessed at that gap with a hardcoded duration is what
    /// flaked. Tests wait on this instead, once, and then assert against a settled app.
    static let homeSeedingComplete = "home.seedingComplete"

    /// The URL field on the reference-link editor (ADR 0167) — the gate that says *this sheet is
    /// open*.
    ///
    /// It exists because the two obvious gates both failed. `navigationBars["Add a link"]` is not
    /// dependable for a sheet (`capture()` learned the same and resolves the title inside the bar's
    /// subtree), and it is a phrase the presenting screen's own button already carries, so it is one
    /// mistake away from being satisfiable before the sheet opens at all. `buttons["Paste"]` was the
    /// second attempt: `PasteButton` is a system control whose exposed label is Apple's to change
    /// and to localise, so gating on it is a guess about somebody else's accessibility text.
    /// An identifier we set ourselves is neither.
    static let referenceLinkField = "reference.linkField"

    /// The control that opens a take's own screen (ADR 0174) — the title half of a take row, which
    /// is a separate button from the play glyph beside it.
    ///
    /// An identifier rather than a label prefix, for the reason the harness keeps relearning: the
    /// button's label is its whole line concatenated — name, duration, note marker, time — and the
    /// only stable part of it is the word *Take*, which is also the prefix of the Journal's **Takes**
    /// filter sitting a few points above it. A prefix match found the filter first, tapped it, and
    /// reported that the take had been opened. The row is the thing being aimed at, so the row says
    /// so itself.
    static let takeRowOpen = "take.rowOpen"

    /// The **Add note here** control in the take screen's Moments section (ADR 0175).
    ///
    /// An identifier for the same reason `takeRowOpen` is one, one step worse: the take's actions
    /// menu carries an item with the *same words*, so a label match has two hits on one screen and
    /// picks whichever the query orders first. The section's button is the one the shoot aims at.
    static let takeAddMoment = "take.addMoment"
}
