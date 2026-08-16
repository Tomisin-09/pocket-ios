import Foundation

/// Whether XCUITest is driving this process (ADR 0146 pass 2).
///
/// The `CommandLine.arguments.contains("-uiTesting")` idiom had grown to five hand-written copies
/// (`Analytics`, `StoreManager`, `OrientationGate`, `HomeView+ProfileMoment`, `RowDeletionCoordinator`);
/// pass 1's ADR flagged the duplication for collapsing here, where the launch seam is being touched
/// anyway. One accessor also means one place to read to answer "what does the app do differently
/// under test?", which is a question worth being able to answer quickly.
///
/// `static let` rather than a computed property: launch arguments cannot change after launch, so
/// this is a constant, and evaluating it once is both cheaper and — being immutable and `Sendable` —
/// safe to read from any isolation under Swift 6.
enum UITestRuntime {
    static let isActive = CommandLine.arguments.contains(UITestHooks.launchArgument)

    /// The hour Home's greeting should be computed from, when the shoot has named one.
    ///
    /// `nil` in every normal launch, and the caller falls back to the real clock — so this is a
    /// seam for the manual's screenshots (see `UITestHooks.shotHourArgument`), not a setting.
    static let shotHour: Int? = parseShotHour(in: CommandLine.arguments)

    /// Split out from the `static let` so it can be tested: a launch argument cannot be varied
    /// inside a running process, which would otherwise make this the one piece of launch parsing
    /// with no way to check its edge cases.
    ///
    /// **Requires `-uiTesting` as well.** The override changes what the app displays, so it should
    /// not be reachable by a stray argument on a build a player is holding — and requiring the flag
    /// that already means "a test is driving this" keeps the number of ways the app can lie about
    /// itself at one.
    ///
    /// Anything malformed returns `nil` rather than a default hour: a shoot that asked for 19:00 and
    /// silently got 09:00 would produce a wrong figure that looks right, whereas falling back to the
    /// real clock gives the same disagreement the harness already knows how to spot.
    static func parseShotHour(in arguments: [String]) -> Int? {
        guard arguments.contains(UITestHooks.launchArgument),
              let flag = arguments.firstIndex(of: UITestHooks.shotHourArgument)
        else { return nil }

        let value = arguments.index(after: flag)
        guard value < arguments.endIndex,
              let hour = Int(arguments[value]),
              (0...23).contains(hour)
        else { return nil }
        return hour
    }
}
