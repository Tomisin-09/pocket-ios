import UserNotifications

/// **The only place the app reads or asks for notification permission** (ADR 0186 D5).
///
/// Every member is `nonisolated static` and reaches for `UNUserNotificationCenter.current()` at the
/// point of use rather than storing it. That is not style — it is the trap `TrialReminder`'s
/// `usesSystemNotifications` documents: the centre is not `Sendable` in the SDK CI builds against
/// (Xcode 16) though it is in a newer one, so holding it as a property of a `@MainActor` type puts
/// it in that actor's isolation region and passing it into an async context **compiles clean locally
/// and fails CI** with *"sending risks causing data races"*. With nothing isolated here there is no
/// region to send it out of, on any SDK.
enum NotificationAuthorization {

    /// Read the current permission **without asking for it**.
    ///
    /// This is the call the app did not make before ADR 0186 — see `NotificationPermission` for why
    /// its absence is a bug rather than a missing nicety.
    static func current() async -> NotificationPermission {
        permission(for: await UNUserNotificationCenter.current().notificationSettings()
            .authorizationStatus)
    }

    /// Ask for permission, but **only when the prompt is still available**.
    ///
    /// On `.denied` this returns `.denied` immediately without calling `requestAuthorization`. The
    /// call would have been harmless in itself — it also returns false without showing anything —
    /// but routing it through here means the caller gets `.denied` rather than a `false` it cannot
    /// interpret, and can offer the Settings app instead of silently reverting a control.
    ///
    /// - Returns: the permission **after** the prompt, so a caller never has to re-read it.
    static func request(options: UNAuthorizationOptions = [.alert, .sound]) async
        -> NotificationPermission {
        let existing = await current()
        guard existing.next == .ask else { return existing }
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: options)) ?? false
        return granted ? .granted : .denied
    }

    private static func permission(for status: UNAuthorizationStatus) -> NotificationPermission {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        // `.provisional` and `.ephemeral` both deliver. Neither is used here — provisional
        // authorization is rejected in ADR 0186's alternatives, because a reminder the player never
        // consciously agreed to is the app deciding to reach them — but mapping them to `.granted`
        // keeps this exhaustive over what the system can actually report.
        case .authorized, .provisional, .ephemeral: .granted
        @unknown default: .denied
        }
    }
}
