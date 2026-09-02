import SwiftUI

/// The **reminder defaults** row in Settings ▸ Practice (ADR 0186 D12).
///
/// **The hub does not grow for this.** ADR 0162 D2 groups Settings by *"what am I trying to
/// change?"*, and a reminder changes how you practise — so it joins the existing **Practice**
/// destination rather than becoming a tenth row. `check-manual.py`'s C1 destination count is
/// untouched.
///
/// **This screen sets a starting position, not an appointment** (ADR 0163's two doors). The
/// reminder itself is switched on *on the routine*, where you are using it; what lives here is the
/// days and time a new one starts from, so a player whose week is Tuesday and Thursday sets that
/// once instead of on every routine. Changing it never reaches a reminder already set — that would
/// be the app rescheduling an appointment somebody else made.
///
/// There is deliberately **no global on switch**. One would arm every routine at once, which is the
/// app deciding you should be reminded rather than you asking to be.
struct PracticeReminderSection: View {
    @Environment(PracticeReminder.self) private var practiceReminder
    /// Held locally and written through, because `defaultSchedule` is a computed `UserDefaults`
    /// read: bound directly, each keystroke of the picker would decode and re-encode JSON.
    @State private var draft = PracticeReminderPlan.Schedule.unset
    /// Whether notifications are allowed at all (ADR 0186 D5) — read, never asked for. Opening
    /// Settings is not a request to be notified.
    @State private var permission: NotificationPermission?

    var body: some View {
        Section {
            WeekdayPicker(weekdays: weekdayBinding)
            DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
        } header: {
            Text("Reminder defaults")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Where a new routine reminder starts. Switch one on from the routine itself. "
                     + "Red Moon never notices when you don't practise, so nothing follows a "
                     + "missed reminder.")
                if practiceReminder.hasAnyReminder(), permission == .denied {
                    NotificationsOffNote(
                        message: "Notifications are off for Red Moon, so reminders can't be "
                            + "delivered. Everything else works as it does now.")
                }
            }
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
        }
        .task {
            draft = practiceReminder.defaultSchedule
            permission = await NotificationAuthorization.current()
        }
    }

    private var weekdayBinding: Binding<Set<Int>> {
        Binding(get: { draft.weekdays }, set: { draft.weekdays = $0; write() })
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: draft.hour,
                                                           minute: draft.minute)) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft.hour = parts.hour ?? draft.hour
                draft.minute = parts.minute ?? draft.minute
                write()
            })
    }

    private func write() { practiceReminder.defaultSchedule = draft }
}

#Preview {
    Form { PracticeReminderSection() }
        .environment(PracticeReminder(usesSystemNotifications: false))
}
