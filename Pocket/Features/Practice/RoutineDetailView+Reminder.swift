import SwiftUI

/// The routine's **reminder** section (ADR 0186 D1–D7, D12), split out of `RoutineDetailView` to
/// keep that file under the 400-line cap.
///
/// **It is set here, on the routine, because this is where you use it** (ADR 0163). Settings ▸
/// Practice holds only the days and time a *new* reminder starts from; the appointment itself
/// belongs to the thing it points at.
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
            Section {
                Toggle(isOn: reminderBinding) {
                    Text("Remind me")
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                }
                .tint(PocketColor.practice)
                .listRowBackground(PocketColor.background)

                if reminderSchedule.isOn {
                    WeekdayPicker(weekdays: weekdayBinding)
                        .listRowBackground(PocketColor.background)
                    DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                        .listRowBackground(PocketColor.background)
                }
            } header: {
                Text("Reminder")
            } footer: {
                reminderFooter
            }
        }
    }

    /// **Future tense, and nothing else** (ADR 0186 D7). "Next: Monday at 18:00" — what is waiting,
    /// never how long it has been, never how many were missed. D2's silence has no copy at all,
    /// which is what makes it silence.
    @ViewBuilder
    private var reminderFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if reminderSchedule.isOn {
                if let next = PracticeReminderPlan.nextFireDate(for: reminderSchedule, after: .now) {
                    Text("Next: \(next.formatted(.dateTime.weekday(.wide).hour().minute()))")
                } else {
                    Text("Pick at least one day.")
                }
            } else {
                Text("A reminder on the days you choose. Red Moon never notices when you don't "
                     + "practise, so nothing follows a missed one.")
            }
            if reminderSchedule.isOn, notificationPermission == .denied {
                NotificationsOffNote(
                    message: "Notifications are off for Red Moon, so this reminder can't be "
                        + "delivered. The routine is still here whenever you open the app.")
            }
        }
        .font(.futura(.caption))
        .foregroundStyle(PocketColor.textSecondary)
    }

    // MARK: - Bindings

    var reminderSchedule: PracticeReminderPlan.Schedule {
        practiceReminder.schedule(for: routine.uid)
    }

    /// Switching it on asks for permission **only if the prompt is still available** (ADR 0186 D5),
    /// and the intent is recorded either way — see `NotificationPermission` for why a denial must
    /// not silently revert the control.
    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { reminderSchedule.isOn },
            set: { wants in
                var updated = reminderSchedule
                updated.isOn = wants
                writeReminder(updated)
                guard wants else { return }
                Task { notificationPermission = await NotificationAuthorization.request() }
            })
    }

    private var weekdayBinding: Binding<Set<Int>> {
        Binding(get: { reminderSchedule.weekdays },
                set: { days in
                    var updated = reminderSchedule
                    updated.weekdays = days
                    writeReminder(updated)
                })
    }

    /// The pickers speak `Date`; the schedule stores an hour and a minute, because an appointment is
    /// a time of day and not an instant — a stored `Date` would carry a day with it and be wrong
    /// from the next morning onwards.
    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderSchedule.hour,
                                                           minute: reminderSchedule.minute)) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                var updated = reminderSchedule
                updated.hour = parts.hour ?? updated.hour
                updated.minute = parts.minute ?? updated.minute
                writeReminder(updated)
            })
    }

    /// The routine's **current** name and block count go with every write, so a rename reaches the
    /// pending request — the content of a scheduled notification is fixed when it is added and
    /// cannot be edited in place.
    private func writeReminder(_ schedule: PracticeReminderPlan.Schedule) {
        practiceReminder.setSchedule(schedule, for: routine.uid,
                                     name: routine.name, blockCount: routine.items.count)
    }
}

/// The days of the week as seven toggles, in the locale's own week order.
///
/// Its own view rather than seven buttons inline, because `firstWeekday` differs by locale (Sunday
/// in the US, Monday across most of Europe) and the ordering has to be derived once rather than at
/// each call site. The values are `Calendar` weekdays — 1 = Sunday — all the way down to
/// `DateComponents.weekday`, so nothing translates.
struct WeekdayPicker: View {
    @Binding var weekdays: Set<Int>

    private var ordered: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ordered, id: \.self) { day in
                let isOn = weekdays.contains(day)
                Text(symbol(day))
                    .font(.futura(.caption, weight: isOn ? .bold : .regular))
                    .foregroundStyle(isOn ? PocketColor.background : PocketColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(isOn ? PocketColor.practice : PocketColor.surfaceStandard, in: Capsule())
                    .contentShape(Capsule())
                    .onTapGesture { toggle(day) }
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                    .accessibilityLabel(fullSymbol(day))
            }
        }
        .padding(.vertical, 4)
    }

    private func toggle(_ day: Int) {
        if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
    }

    /// The single-letter symbol, which is not unique in English ("S", "T") — hence the full name on
    /// the accessibility label rather than the initial.
    private func symbol(_ day: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return symbols.indices.contains(day - 1) ? symbols[day - 1] : ""
    }

    private func fullSymbol(_ day: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        return symbols.indices.contains(day - 1) ? symbols[day - 1] : ""
    }
}
