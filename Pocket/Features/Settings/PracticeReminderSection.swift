import SwiftData
import SwiftUI

/// The **reminder** rows in Settings ▸ Practice (ADR 0186 D12) — a starting point for new reminders,
/// and a list of the ones that actually exist.
///
/// **The hub does not grow for this.** ADR 0162 D2 groups Settings by *"what am I trying to
/// change?"*, and a reminder changes how you practise — so it joins the existing **Practice**
/// destination rather than becoming a tenth row. `check-manual.py`'s C1 destination count is
/// untouched.
///
/// **This screen sets a starting position, not an appointment** (ADR 0163's two doors). The reminder
/// itself is switched on *on the routine*, where you are using it; what lives here is the days and
/// time a new one starts from, so a player whose week is Tuesday and Thursday sets that once instead
/// of on every routine. Changing it never reaches a reminder already set — that would be the app
/// rescheduling an appointment somebody else made. There is deliberately **no global on switch**:
/// one would arm every routine at once, which is the app deciding you should be reminded rather than
/// you asking to be.
///
/// ## Why it is shaped like this, which is not how it shipped
///
/// The first version was the two pickers and one sentence of explanation **in the footer**, below
/// them. On device that reads as a reminder you can set here — it is the routine's own control
/// minus its toggle — so it was set, and nothing fired, and nothing on screen said why until after
/// the controls had been used (owner feedback, 2026-09-02). Two near-identical controls where only
/// one of them fires is a design fault, not a misreading.
///
/// Three things answer it, and the third is the one that would have prevented the question:
///
/// 1. The explanation is **above** the pickers, so it is read before they are touched.
/// 2. The header names what they are — a starting point — rather than "defaults", which says
///    nothing about whether the thing is live.
/// 3. **The reminders that do exist are listed**, by routine and schedule, and each one **opens for
///    editing**. That turns a control which appears broken into a page that answers "what is
///    actually set, and where do I change it?".
struct PracticeReminderSection: View {
    /// Raised to the host, because a `.sheet` attached inside a `Form`'s `Section` does not present
    /// — the trap `RoutineDetailView+References` records. `PracticeSettingsView` owns the
    /// presentation; this section only says which row was tapped.
    @Binding var editing: RoutineReminderTarget?

    @Environment(PracticeReminder.self) private var practiceReminder
    /// Names for the list below. Fetched whole and filtered in memory — the house pattern, and a
    /// `#Predicate` has nothing to filter on here anyway, since which routines have reminders is
    /// known to `PracticeReminder` and not to the store.
    @Query(sort: \Routine.name) private var routines: [Routine]
    /// Held locally and written through. The pickers mutate a draft and the draft is committed, so
    /// a partially-built change never round-trips through storage mid-gesture.
    @State private var draft = PracticeReminderPlan.Schedule.unset
    /// Whether notifications are allowed at all (ADR 0186 D5) — read, never asked for. Opening
    /// Settings is not a request to be notified.
    @State private var permission: NotificationPermission?

    var body: some View {
        // First, above everything about reminders: while notifications are off, nothing in the two
        // sections below can happen. It used to sit in the *last* footer on the screen, in the
        // smallest type on it — see `NotificationsOffNote`.
        if !isDeliverable, !scheduled.isEmpty {
            Section {
                NotificationsOffNote(
                    message: "Notifications are off for Red Moon, so your reminders can't be "
                        + "delivered. They stay exactly as you set them, and everything else in "
                        + "the app works as it does now.")
                    .listRowBackground(PocketColor.background)
            }
        }

        Section {
            Text("A reminder is switched on from the routine itself. This only sets the days and "
                 + "time a new one starts from — nothing here sends anything.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            WeekdayPicker(weekdays: weekdayBinding)
            DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
        } header: {
            Text("Starting point for new reminders")
        }

        Section {
            if scheduled.isEmpty {
                Text("None yet. Open a routine and switch on Remind me.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                ForEach(scheduled) { entry in
                    Button { editing = entry } label: { reminderRow(entry) }
                        .buttonStyle(.plain)
                        .listRowBackground(PocketColor.background)
                }
            }
        } header: {
            Text("Reminders you've set")
        } footer: {
            Text("Red Moon never notices when you don't practise, so nothing follows a missed "
                 + "reminder.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .task {
            draft = practiceReminder.defaultSchedule
            permission = await NotificationAuthorization.current()
        }
    }

    /// A routine's name, when it is due, and a way in.
    ///
    /// **It opens `RoutineReminderSheet`, not the routine.** Every other door into a routine is
    /// behind `proGated(.routine)` (ADR 0144 D4); this one needs no gate because it reaches no Pro
    /// surface — only the reminder, which the player already owns. See that sheet for why turning a
    /// notification *off* must never be the gated half.
    private func reminderRow(_ entry: RoutineReminderTarget) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(summary(entry) ?? "")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                if !isDeliverable {
                    Text("Not being delivered")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .opacity(isDeliverable ? 1 : 0.55)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// A schedule this row can state as a fact. **Only when it can actually arrive** — with
    /// notifications denied, "Mon, Wed & Fri at 08:00" describes something that will not happen, so
    /// the row says so in words rather than leaving the fade to carry it. A dim row is a hint; only
    /// a sentence survives VoiceOver, and only a sentence is unambiguous at a glance.
    private var isDeliverable: Bool { permission != .denied }

    private func summary(_ entry: RoutineReminderTarget) -> String? {
        PracticeReminderPlan.summary(for: practiceReminder.schedule(for: entry.uid))
    }

    /// The routines with a reminder switched on, in name order.
    ///
    /// A routine whose schedule is on but has no days left ticked contributes no summary and is
    /// dropped — `PracticeReminderPlan.summary` returns `nil` for exactly that state, and listing it
    /// would name a reminder that cannot fire.
    private var scheduled: [RoutineReminderTarget] {
        routines.compactMap { routine in
            let schedule = practiceReminder.schedule(for: routine.uid)
            guard PracticeReminderPlan.summary(for: schedule) != nil else { return nil }
            return RoutineReminderTarget(
                uid: routine.uid,
                name: routine.name.isEmpty ? "Untitled routine" : routine.name,
                blockCount: routine.items.count)
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

    private func write() { practiceReminder.setDefaultSchedule(draft) }
}

#Preview {
    Form { PracticeReminderSection(editing: .constant(nil)) }
        .environment(PracticeReminder(usesSystemNotifications: false))
        .modelContainer(for: Routine.self, inMemory: true)
}
