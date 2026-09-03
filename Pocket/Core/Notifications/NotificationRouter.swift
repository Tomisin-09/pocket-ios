import Foundation
import Observation

/// **Where a tapped notification lands** (ADR 0186 D6).
///
/// A notification whose tap opens Home has wasted the only interaction it gets, so the reminder
/// carries the routine's `uid` and this carries it from `AppDelegate` to the view that can act on
/// it.
///
/// **Why a singleton, when almost nothing else in this app is one.** The tap arrives at
/// `UNUserNotificationCenterDelegate`, which is a `UIApplicationDelegate` responsibility and lives
/// outside the SwiftUI environment entirely — there is no view to inject into and no `@State` for
/// the delegate to reach. `AppDelegate.orientationMask` is a static for exactly this reason
/// (ADR 0042). The alternative is a global that is not observable, which just moves the problem.
///
/// **It is a mailbox, not a state.** The uid is *consumed*: read once and cleared. A pending route
/// that stayed set would re-open the routine every time the reading view re-appeared, which is a
/// notification reaching the player more than once from a single tap.
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// The routine a tap asked for, until someone takes it. Observable, so a view already on screen
    /// reacts; readable on appear, so a **cold launch** — where the tap is delivered before any view
    /// exists — is the same code path rather than a second one.
    private(set) var pendingRoutineUID: UUID?

    private init() {}

    func open(routineUID: UUID) {
        pendingRoutineUID = routineUID
    }

    /// Take the pending route, if any, and clear it.
    ///
    /// A caller that cannot resolve the uid still consumes it, and that is deliberate: an unresolved
    /// route means the routine is gone, and the correct behaviour is Home saying nothing (D6). This
    /// is D3's failure mode after the sweep has been missed, and it must degrade quietly rather
    /// than trap.
    func consumeRoutineUID() -> UUID? {
        defer { pendingRoutineUID = nil }
        return pendingRoutineUID
    }
}
