import Foundation
import Observation
import UserNotifications

/// The **side-effecting half** of the practice reminder (ADR 0186 D4): it owns the pending
/// notification requests and the stored schedules. Every *decision* is delegated to
/// `PracticeReminderPlan`, which is pure and unit-tested; this type only does what a test cannot.
///
/// This is the third instance of a shape the app already runs twice (`TrialReminder`, ADR 0144 D6;
/// `DiagnosticsRecorder`, ADR 0183 D5), for the reason all three share: nothing here fails loudly.
/// A reminder that should not have fired looks like nothing at all until it lands on a device.
///
/// **Storage is `UserDefaults`, not SwiftData.** ADR 0186 adds no `@Model`, no field and no
/// migration — one schedule per routine, JSON under a `uid`-keyed name. A reminder is a setting, not
/// practice history, and keeping it out of the store is what lets this ship against a schema frozen
/// for review.
///
/// **Local notifications only.** No `aps-environment` and no push server: AGENTS.md forbids
/// entitlements the app doesn't exercise, and ADR 0113 keeps the app account-free, so there is no
/// address to mail. Server-side re-engagement is not declined here so much as structurally
/// unavailable.
@MainActor
@Observable
final class PracticeReminder {

    private let defaults: UserDefaults

    /// Whether this instance talks to the system notification centre at all — `false` in previews
    /// and unit tests.
    ///
    /// Deliberately a **flag, not a stored `UNUserNotificationCenter`**, and the reason is inherited
    /// rather than rediscovered: the centre is not `Sendable` in the SDK CI builds against (Xcode
    /// 16) though it is in a newer one, so holding it as a property of a `@MainActor` type and
    /// passing it into an async context **compiles clean locally and fails CI**. See
    /// `TrialReminder.usesSystemNotifications`, which pays for this lesson in full.
    private let usesSystemNotifications: Bool

    init(defaults: UserDefaults = .standard, usesSystemNotifications: Bool = true) {
        self.defaults = defaults
        self.usesSystemNotifications = usesSystemNotifications
    }

    // MARK: - Schedules

    private func storageKey(_ routineUID: UUID) -> String {
        "practiceReminder.\(routineUID.uuidString)"
    }

    /// The days and time a routine's reminder **starts** at when it is first switched on
    /// (ADR 0186 D12) — set in Settings ▸ Practice, per ADR 0163's second door.
    ///
    /// A default, and nothing more: changing it never reaches a routine whose reminder is already
    /// set, because that would be the app rescheduling an appointment the player made. Its own
    /// `isOn` is meaningless and always read as `false` — a global switch that armed every routine
    /// at once is not a thing this feature has.
    var defaultSchedule: PracticeReminderPlan.Schedule {
        get {
            guard let data = defaults.data(forKey: Key.defaultSchedule),
                  let stored = try? JSONDecoder().decode(
                    PracticeReminderPlan.Schedule.self, from: data)
            else { return .unset }
            return stored
        }
        set {
            var stored = newValue
            stored.isOn = false
            guard let data = try? JSONEncoder().encode(stored) else { return }
            defaults.set(data, forKey: Key.defaultSchedule)
        }
    }

    private enum Key {
        /// Deliberately **outside** the `practiceReminder.` prefix that `storedRoutineUIDs` scans, so
        /// the default can never be mistaken for a routine's schedule by a sweep.
        static let defaultSchedule = "practiceReminderDefault"
    }

    /// The schedule stored for a routine, or — when it has none — the player's default with `isOn`
    /// off, so switching the reminder on starts from the days and time they usually choose.
    ///
    /// A routine with no stored schedule and one that was explicitly switched off are the same thing
    /// as far as *firing* goes, on purpose: both mean nothing fires, and neither is a fact about the
    /// player worth keeping apart.
    func schedule(for routineUID: UUID) -> PracticeReminderPlan.Schedule {
        guard let data = defaults.data(forKey: storageKey(routineUID)),
              let stored = try? JSONDecoder().decode(PracticeReminderPlan.Schedule.self, from: data)
        else {
            var starting = defaultSchedule
            starting.isOn = false
            return starting
        }
        return stored
    }

    /// Whether any routine has a reminder switched on — drives the Settings row's summary, without
    /// that row needing to know how schedules are stored.
    func hasAnyReminder() -> Bool {
        storedRoutineUIDs().contains { schedule(for: $0).isOn }
    }

    /// Record what the player asked for, and bring the pending requests in line with it.
    ///
    /// - Parameters:
    ///   - name: the routine's name, for the notification's title (D7). Passed in on every call
    ///     rather than stored, so a **rename** is picked up the next time this runs — the content of
    ///     a pending request is fixed at schedule time and cannot be edited in place.
    ///   - blockCount: how many blocks it has, for the body. A fact about the material, in the same
    ///     grammar `RecentRoutineCard` uses.
    func setSchedule(_ schedule: PracticeReminderPlan.Schedule,
                     for routineUID: UUID,
                     name: String,
                     blockCount: Int) {
        if let data = try? JSONEncoder().encode(schedule) {
            defaults.set(data, forKey: storageKey(routineUID))
        }
        apply(schedule, routineUID: routineUID, name: name, blockCount: blockCount)
    }

    /// Re-apply a routine's stored schedule against its current name and block count. Idempotent —
    /// the identifiers are fixed, so this replaces rather than stacks — and cheap enough to call
    /// whenever the routine screen opens or saves, which is how a rename reaches a pending request.
    func refresh(routineUID: UUID, name: String, blockCount: Int) {
        apply(schedule(for: routineUID), routineUID: routineUID, name: name, blockCount: blockCount)
    }

    // MARK: - Cancelling (ADR 0186 D3)

    /// Drop a routine's reminders and forget its schedule. Called from the routine's delete path.
    ///
    /// Takes a `uid` rather than a `Routine`, which is what makes it callable from a delete closure
    /// that has already given up its model object — and from `reconcile`, where the routine is gone
    /// by definition.
    func cancel(routineUID: UUID) {
        defaults.removeObject(forKey: storageKey(routineUID))
        guard usesSystemNotifications else { return }
        let identifiers = PracticeReminderPlan.weekdayRange.map {
            PracticeReminderPlan.identifier(routineUID: routineUID, weekday: $0)
        }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// **The sweep that actually holds** (ADR 0186 D3). Drops every pending request whose routine no
    /// longer resolves, and every stored schedule likewise.
    ///
    /// The delete path cancels too, and that is the version which looks correct in review and fails
    /// on a path nobody listed: a cascade delete, a Pro-lapse sweep or a future bulk action can
    /// remove a routine without routing through the row-delete handler. `getPendingNotificationRequests`
    /// is the only source of truth about what the **system** still holds — the app's own bookkeeping
    /// is exactly what would be wrong in that case.
    ///
    /// It matters more here than the same shape does for the trial reminder. An orphan does not sit
    /// quietly in a list waiting to be found; it reaches the player on their lock screen, outside the
    /// app, naming something the app has already forgotten. This is ADR 0151 — *a take outlives its
    /// loop* — with the wreckage in a place the app cannot see.
    func reconcile(liveRoutineUIDs: Set<UUID>) async {
        for stored in storedRoutineUIDs() where !liveRoutineUIDs.contains(stored) {
            defaults.removeObject(forKey: storageKey(stored))
        }
        guard usesSystemNotifications else { return }
        let pending = await Self.pendingIdentifiers()
        let orphaned = pending.filter { identifier in
            guard let uid = PracticeReminderPlan.routineUID(fromIdentifier: identifier)
            else { return false }   // Not ours — the trial reminder shares this centre.
            return !liveRoutineUIDs.contains(uid)
        }
        guard !orphaned.isEmpty else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: orphaned)
    }

    /// `nonisolated`, so the non-`Sendable` centre never crosses an isolation boundary — the same
    /// reason `usesSystemNotifications` is a flag. Every other call here is synchronous and has no
    /// boundary to cross.
    private nonisolated static func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    /// The routines this type holds a schedule for, recovered from the defaults keys themselves so
    /// there is no separate index to fall out of step with what is actually stored.
    private func storedRoutineUIDs() -> [UUID] {
        defaults.dictionaryRepresentation().keys.compactMap { key in
            guard key.hasPrefix("practiceReminder.") else { return nil }
            return UUID(uuidString: String(key.dropFirst("practiceReminder.".count)))
        }
    }

    // MARK: - The notifications themselves

    private func apply(_ schedule: PracticeReminderPlan.Schedule,
                       routineUID: UUID,
                       name: String,
                       blockCount: Int) {
        guard usesSystemNotifications else { return }
        let notifications = UNUserNotificationCenter.current()
        // Clear every weekday first, so a day the player just unticked goes away without this having
        // to work out which days changed.
        notifications.removePendingNotificationRequests(
            withIdentifiers: PracticeReminderPlan.weekdayRange.map {
                PracticeReminderPlan.identifier(routineUID: routineUID, weekday: $0)
            })

        for request in PracticeReminderPlan.requests(for: schedule, routineUID: routineUID) {
            var components = DateComponents()
            components.weekday = request.weekday
            components.hour = request.hour
            components.minute = request.minute
            // Repeating, so it counts **once** against iOS's 64-request ceiling however often it
            // fires: seven weekdays is seven requests, and there is no rolling re-arm to get wrong.
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            notifications.add(UNNotificationRequest(identifier: request.identifier,
                                                    content: content(name: name,
                                                                     blockCount: blockCount,
                                                                     routineUID: routineUID),
                                                    trigger: trigger))
        }
    }

    /// **Future tense, names the material, never narrates the player** (ADR 0186 D7).
    ///
    /// > Morning warm-up · 4 blocks
    ///
    /// Not "Time to practise!", not "Don't lose your progress", and never a second person past tense
    /// about failure. It says what is waiting, the way the routine's own card says it — which is
    /// also why there is no exclamation mark and no verb addressed to the reader.
    private func content(name: String, blockCount: Int, routineUID: UUID)
        -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = name.isEmpty ? "Your routine" : name
        content.body = blockCount == 1 ? "1 block" : "\(blockCount) blocks"
        content.sound = .default
        // The **`uid`**, never a `persistentModelID` (ADR 0090): this payload outlives launches, and
        // a `PersistentIdentifier` is not stable across the store's lifetime.
        content.userInfo = [Self.routineUIDKey: routineUID.uuidString]
        return content
    }

    /// The one key in a reminder's payload.
    ///
    /// **`nonisolated`**, because the reader is `AppDelegate`'s nonisolated tap callback — see the
    /// note on that extension for why it cannot be on the main actor. A `let String` has nothing to
    /// race on, so this costs nothing.
    nonisolated static let routineUIDKey = "routineUID"
}
