import SwiftUI
import UserNotifications

// Per-screen orientation control (ADR 0042). Pure SwiftUI has no first-class per-view
// orientation lock, so the app is portrait-locked by default and individual screens opt
// into landscape. `Info.plist` lists the allowed orientations app-wide (portrait +
// landscape); this gate narrows them per screen by driving the app delegate's
// `supportedInterfaceOrientationsFor` from app state. Without the gate every screen would
// become rotatable the moment landscape is added to `Info.plist`.

/// App delegate: answers UIKit's orientation query from a mutable mask, and — since ADR 0186 D6 —
/// receives notification taps.
///
/// **The second job is unrelated to the first, and that is a real (small) cost noted rather than
/// hidden.** A `UNUserNotificationCenterDelegate` must be set *before the app finishes launching*,
/// or a tap that woke the app cold is delivered to nobody; `@UIApplicationDelegateAdaptor` on
/// `PocketApp` is the app's only hook that early, and introducing a second delegate to keep this
/// file single-purpose would mean two of them competing for the same registration. The tap handling
/// itself lives in the extension at the foot of this file, and it does one thing: hand a `uid` to
/// `NotificationRouter`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// The orientations currently allowed. Defaults to portrait — only a screen that opts
    /// in (via `.landscapeEnabled()`) widens it, and reverts on disappear.
    static var orientationMask: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Install the global Futura navigation-title appearance once, before any bar is built
        // (ADR 0110). Isolated here so the whole feature is this call plus `NavigationBarStyle`.
        NavigationBarStyle.apply()
        // Stamp the install date once (ADR 0120). Local bookkeeping, written regardless of
        // analytics consent — it is the user's own state, and only ever leaves the device as a
        // coarse age bucket, and only then if consent is later given.
        AppSettings.recordInstallDateIfNeeded()
        // Seed the regional analytics default once, before any view reads it (ADR 0147). The value
        // differs by law — off in the EEA under ePrivacy Art 5(3), on in the UK and rest of world
        // under DUAA 2025 Sch A1 para 5 — so it cannot be a hardcoded `@AppStorage` default. Writing
        // it here means the key always exists by the time Settings or the sheet reads it, and an
        // explicit decline recorded under ADR 0120 survives untouched.
        AppSettings.seedAnalyticsDefaultIfNeeded(
            model: AnalyticsPolicy.consentModel(regionCode: Locale.current.region?.identifier))
        // Kill animations under UI test (ADR 0146). XCUITest blocks on app-idle before every
        // query and every tap, so each transition's duration is spent by the *test*, not just
        // by the app — and a loaded CI runner multiplies it. Done here rather than in the tests
        // because it has to land before the first view is built.
        if UITestRuntime.isActive {
            UIView.setAnimationsEnabled(false)
        }
        // Receive notification taps (ADR 0186 D6). Set here, in `didFinishLaunching`, because a tap
        // that launched the app cold is delivered to the delegate as soon as launch completes — set
        // it any later and that delivery has already been dropped, silently, on exactly the path
        // that matters most.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationMask
    }
}

/// Sets the allowed orientation mask and asks the active scene to re-evaluate it, so a
/// revert to `.portrait` actively rotates the device back if it's currently in landscape.
enum OrientationGate {
    // Touches `UIApplication.shared` and the scene's geometry, all main-actor APIs (and
    // `AppDelegate.orientationMask` is main-actor isolated too), so the call must be on the
    // main actor — Swift 6 enforces this. The `.onAppear`/`.onDisappear` callers already are.
    @MainActor
    static func set(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationMask = mask
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

private struct LandscapeEnabled: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { OrientationGate.set([.portrait, .landscape]) }
            .onDisappear { OrientationGate.set(.portrait) }
    }
}

extension View {
    /// Opt this screen into landscape; reverts to portrait-only (rotating back if needed)
    /// when it disappears. ADR 0042: only the practice screen uses this.
    func landscapeEnabled() -> some View {
        modifier(LandscapeEnabled())
    }
}

/// Notification taps (ADR 0186 D6), kept apart from the orientation work above so the two
/// responsibilities at least read separately.
///
/// It resolves nothing and navigates nothing — it reads a `uid` out of the payload and posts it.
/// Resolving a `uid` needs a `ModelContext`, which is a SwiftUI-environment thing and not something
/// an app delegate should be reaching for; `HomeView` does that, where the store already is.
///
/// **Both methods are `nonisolated`, and they have to be.** `UIApplicationDelegate` conformance
/// makes `AppDelegate` main-actor isolated, but these protocol requirements are not — so a
/// main-actor implementation means the caller sends `UNUserNotificationCenter`,
/// `UNNotificationResponse` and `UNNotification` across an isolation boundary, none of which is
/// `Sendable`, and the build fails with *"non-Sendable parameter type … cannot be sent from caller
/// of protocol requirement"*. This is the third face of the trap `TrialReminder`'s
/// `usesSystemNotifications` documents: the fix is the same one, which is to keep the notification
/// types out of an actor's region entirely and hop with a **value** — here a `UUID`.
extension AppDelegate: UNUserNotificationCenterDelegate {

    /// A tap. The **`uid`**, never a `persistentModelID` — see `PracticeReminder.content`.
    ///
    /// The payload is read here, in the nonisolated context, so nothing but the extracted `UUID`
    /// crosses onto the main actor.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let raw = info[PracticeReminder.routineUIDKey] as? String,
              let uid = UUID(uuidString: raw) else { return }
        await MainActor.run { NotificationRouter.shared.open(routineUID: uid) }
    }

    /// Show the reminder even when the app is already open.
    ///
    /// It is an appointment the player made, not an interruption the app decided on, so suppressing
    /// it in the foreground would be the app quietly overruling them. `.banner` only — **no
    /// `.badge`**, ever (ADR 0186 D2): a badge is a running tally of things left undone, which is
    /// the absence frame wearing a number.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
