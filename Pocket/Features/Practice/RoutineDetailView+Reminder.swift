import SwiftUI

/// The routine's **reminder** section (ADR 0186 D1–D7, D12), split out of `RoutineDetailView` to
/// keep that file under the 400-line cap. The controls themselves are `ReminderSection`, shared with
/// the second door in Settings ▸ Practice.
///
/// **It is set here, on the routine, because this is where you use it** (ADR 0163). Settings holds
/// the same appointment behind a list, for when you are looking at your reminders rather than at a
/// routine.
///
/// **It is not part of the Cancel/Save contract, and that is deliberate.** Every other control on
/// this screen writes into the editing sandbox and lives or dies with Save. A reminder is not a
/// property of the routine — there is no `@Model` field and no migration behind it (ADR 0186's
/// header: the schema does not move) — it is a schedule in `UserDefaults` keyed by the routine's
/// `uid`, and it takes effect the moment it is set. Making it provisional would mean a player
/// switching on a reminder, backing out of a screen they were only reading, and silently getting
/// no reminder.
///
/// So it shows in **read-only mode only**, where there is no Save to contradict. In edit mode the
/// screen is about the routine's contents and this row would be the one control on it that ignored
/// Cancel.
extension RoutineDetailView {

    @ViewBuilder
    var reminderSection: some View {
        // Nothing to keep an appointment with until the routine is in the store: a provisional
        // generated session has a `uid`, so the write would succeed, and it would schedule a
        // notification for a routine the player has not yet decided to keep — one that would fire
        // days later naming something that was never saved. That is D3's orphan, created on purpose.
        if existsInStore && !isEditing {
            ReminderSection(
                header: "Reminder",
                schedule: scheduleBinding,
                permission: notificationPermission,
                deniedMessage: "Notifications are off for Red Moon, so this reminder can't be "
                    + "delivered. The routine is still here whenever you open the app.",
                onSwitchedOn: {
                    Task { notificationPermission = await NotificationAuthorization.request() }
                })
        }
    }

    /// Reads through `PracticeReminder` and writes straight back, carrying the routine's **current**
    /// name and block count every time — a rename has to reach the pending request, whose content is
    /// fixed when it is added and cannot be edited in place.
    private var scheduleBinding: Binding<PracticeReminderPlan.Schedule> {
        Binding(
            get: { practiceReminder.schedule(for: routine.uid) },
            set: { updated in
                practiceReminder.setSchedule(updated, for: routine.uid,
                                             name: routine.name, blockCount: routine.items.count)
            })
    }
}
