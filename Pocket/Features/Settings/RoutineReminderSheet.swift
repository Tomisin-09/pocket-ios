import SwiftUI

/// **Editing one routine's reminder from Settings** (ADR 0186 D12, amended).
///
/// The second door onto an appointment whose first door is the routine screen (ADR 0163). It carries
/// the same `ReminderSection`, so the two cannot drift.
///
/// ## It opens the reminder, not the routine
///
/// It opens a **notification the player already owns**. The sheet shows the routine's **name** and
/// its reminder, and offers no way into the routine itself: a Settings row is for changing the
/// appointment, and the routine screen is one tap away from Practice. The shape was first argued
/// while routines sat behind a paywall, so that switching a reminder off could never be the gated
/// half; Red Moon is free now (ADR 0237), and the shape stays for the first reason.
struct RoutineReminderSheet: View {
    let routineUID: UUID
    let routineName: String
    let blockCount: Int

    @Environment(PracticeReminder.self) private var practiceReminder
    @Environment(\.dismiss) private var dismiss
    @State private var permission: NotificationPermission?

    var body: some View {
        NavigationStack {
            Form {
                ReminderSection(
                    header: "Reminder",
                    schedule: scheduleBinding,
                    permission: permission,
                    deniedMessage: "Notifications are off for Red Moon, so this reminder can't be "
                        + "delivered. The routine is still here whenever you open the app.",
                    onSwitchedOn: {
                        Task { permission = await NotificationAuthorization.request() }
                    })
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle(routineName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: .semibold))
                }
            }
        }
        // Read, never asked for (ADR 0186 D5): opening this is not a request to be notified.
        .task { permission = await NotificationAuthorization.current() }
    }

    /// Writes take effect immediately, exactly as they do on the routine screen — there is no Save
    /// here to be consistent with, and a reminder that only applied on Done would be a second
    /// contract for the same control.
    private var scheduleBinding: Binding<PracticeReminderPlan.Schedule> {
        Binding(
            get: { practiceReminder.schedule(for: routineUID) },
            set: { updated in
                practiceReminder.setSchedule(updated, for: routineUID,
                                             name: routineName, blockCount: blockCount)
            })
    }
}

/// What a tapped row hands the sheet. A **value**, never the `Routine`: the sheet outlives the row
/// that built it, and presenting by a model object is how a `persistentModelID` change dismisses a
/// sheet mid-edit (ADR 0090, `docs/swiftdata-gotchas.md`).
struct RoutineReminderTarget: Identifiable, Equatable {
    let uid: UUID
    let name: String
    let blockCount: Int
    var id: UUID { uid }
}
