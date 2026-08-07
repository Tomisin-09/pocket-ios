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
}
