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

    /// Marks Home as **finished seeding**, not merely rendered.
    ///
    /// First-launch seeding is a `.task` that paints Home before it completes, so "Home is on
    /// screen" and "the seeded content exists" are different moments — up to seconds apart on a
    /// cold simulator. Every wait that guessed at that gap with a hardcoded duration is what
    /// flaked. Tests wait on this instead, once, and then assert against a settled app.
    static let homeSeedingComplete = "home.seedingComplete"
}
