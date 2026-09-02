import SwiftUI

/// **The reminder controls** (ADR 0186 D7, D12) — a switch, the days, the time, and a footer that
/// only ever speaks in the future tense.
///
/// One view rather than two copies, because there are now two doors onto the same appointment: the
/// routine's own screen (ADR 0163 — settings where you use them) and the list in Settings ▸
/// Practice. Two implementations of the same three controls would drift, and the half most likely to
/// drift is the footer, which is where every rule about what this feature may *say* is enforced.
///
/// It renders a whole `Section`, so both hosts drop it into their `Form` / `List` unchanged.
struct ReminderSection: View {
    let header: String
    @Binding var schedule: PracticeReminderPlan.Schedule
    /// Notification permission as last read (ADR 0186 D5) — `nil` until the host has looked.
    let permission: NotificationPermission?
    /// What is not being delivered, and what still works without it. Per-host, because "the routine
    /// is still here" and "everything else works as it does now" are different reassurances.
    let deniedMessage: String
    /// Raised when the switch goes **on**, so the host can ask for permission — only ever there,
    /// because that is the moment the player asked for the thing the permission is for (D5).
    let onSwitchedOn: () -> Void

    var body: some View {
        Section {
            Toggle(isOn: isOnBinding) {
                Text("Remind me")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            .tint(PocketColor.practice)
            .listRowBackground(PocketColor.background)

            if schedule.isOn {
                WeekdayPicker(weekdays: $schedule.weekdays)
                    .listRowBackground(PocketColor.background)
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .listRowBackground(PocketColor.background)
            }
        } header: {
            Text(header)
        } footer: {
            footer
        }
    }

    /// **Future tense, and nothing else** (ADR 0186 D7). "Next: Monday at 18:00" — what is waiting,
    /// never how long it has been, never how many were missed. D2's silence has no copy at all,
    /// which is what makes it silence.
    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if schedule.isOn {
                if let next = PracticeReminderPlan.nextFireDate(for: schedule, after: .now) {
                    Text("Next: \(next.formatted(.dateTime.weekday(.wide).hour().minute()))")
                } else {
                    Text("Pick at least one day.")
                }
            } else {
                Text("A reminder on the days you choose. Red Moon never notices when you don't "
                     + "practise, so nothing follows a missed one.")
            }
            if schedule.isOn, permission == .denied {
                NotificationsOffNote(message: deniedMessage)
            }
        }
        .font(.futura(.caption))
        .foregroundStyle(PocketColor.textSecondary)
    }

    private var isOnBinding: Binding<Bool> {
        Binding(get: { schedule.isOn },
                set: { wants in
                    schedule.isOn = wants
                    if wants { onSwitchedOn() }
                })
    }

    /// The picker speaks `Date`; the schedule stores an hour and a minute, because an appointment is
    /// a time of day and not an instant — a stored `Date` would carry a day with it and be wrong
    /// from the next morning onwards.
    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: schedule.hour,
                                                           minute: schedule.minute)) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                schedule.hour = parts.hour ?? schedule.hour
                schedule.minute = parts.minute ?? schedule.minute
            })
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
                    .background(isOn ? PocketColor.practice : PocketColor.surfaceStandard,
                                in: Capsule())
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
