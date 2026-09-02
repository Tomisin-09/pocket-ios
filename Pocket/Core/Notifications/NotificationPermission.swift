import Foundation

/// **What the app is allowed to do about notification permission right now** (ADR 0186 D5).
///
/// The pure half of the permission check: Foundation-only per the "pure logic stays pure" rule
/// (AGENTS.md), so it can be exercised without a notification service. `NotificationAuthorization`
/// is the half that reads the real status.
///
/// **Why this exists at all.** The system prompt appears **once, ever, for the app** — not once per
/// feature. Apple: *"Because the system saves the user's response, calls to this method during
/// subsequent launches do not prompt the user again."* After a denial `requestAuthorization` returns
/// `false` immediately and shows nothing, so an app that only ever calls `requestAuthorization` has
/// no way to tell *"they just said no"* from *"they said no in another feature, months ago"*. Those
/// two need different interfaces, and telling them apart is the whole job of this type.
enum NotificationPermission: Equatable {
    /// The prompt has never been shown. It is still available — exactly once.
    case notDetermined
    /// The prompt was shown and refused. **There is no API to present it again**; the only route
    /// back is the Settings app.
    case denied
    /// Notifications can be delivered (`.authorized`, `.provisional` or `.ephemeral`).
    case granted

    /// What a feature that wants to send a notification should do next.
    ///
    /// Named as three actions rather than a `Bool` because the interesting case — `.denied` — is the
    /// one a `Bool` collapses into "no" and loses. "No, and asking will do nothing, so offer the
    /// Settings app instead" is a different screen from "no".
    enum Next: Equatable {
        /// Ask. The system prompt will actually appear.
        case ask
        /// Already granted — schedule without asking, and show no permission UI at all.
        case proceed
        /// Denied. **Do not call `requestAuthorization`** — it returns `false` silently, which is
        /// indistinguishable from the player having just declined and reads to them as the control
        /// breaking. Say the permission is off and offer `UIApplication.openSettingsURLString`.
        case sendToSettings
    }

    var next: Next {
        switch self {
        case .notDetermined: .ask
        case .granted: .proceed
        case .denied: .sendToSettings
        }
    }

    /// Whether a scheduled request can actually reach the player.
    ///
    /// Distinct from *whether the player wants the reminder*, which is a separate stored flag on
    /// each feature. Conflating the two is the bug ADR 0186 D5 names: one flag written from the
    /// authorization result makes a denial in one feature look like the other feature being switched
    /// off, silently.
    var canDeliver: Bool { self == .granted }
}
