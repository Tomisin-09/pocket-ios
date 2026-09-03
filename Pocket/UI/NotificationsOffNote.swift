import SwiftUI

/// **"Notifications are off, and here is the only way back"** (ADR 0186 D5).
///
/// Shown wherever a reminder the player has switched **on** cannot be delivered. Two surfaces raise
/// it — the routine's own Reminder section and Settings ▸ Practice — which is why it is one view
/// rather than a paragraph copied into each.
///
/// **It leads the reminder controls; it does not trail them.** It first shipped as caption-sized
/// grey text in a section *footer*, which put the one fact that invalidates everything above it at
/// the bottom of the screen, in the smallest type on it, after two sections the player had already
/// read and acted on (owner feedback on device, 2026-09-02). A warning that arrives after the
/// decision it should have informed is decoration.
///
/// So: above the controls, at `.subheadline` rather than `.caption`, on its own filled ground with
/// a struck-through bell. It is deliberately the heaviest thing in the reminder block, because
/// while it is true nothing else in that block can happen.
///
/// **It is still not an alert.** `MicAccessAlert` interrupts because it answers a gesture that was
/// *refused* — the swipe did nothing, so something must say why, once. This reports a standing
/// condition beside controls that did work, and an alert for that would fire on every entry to the
/// screen to deliver news the player can act on whenever they like.
///
/// The Settings app is offered because it is genuinely the only route: the system prompt is
/// one-shot for the whole app, and after a denial there is no API to present it again.
struct NotificationsOffNote: View {
    /// What is not being delivered, and what still works without it. Per-surface, because "the
    /// routine is still here" and "everything else works as it does now" are different
    /// reassurances.
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PocketColor.surfaceStandard, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    Form {
        NotificationsOffNote(message: "Notifications are off for Red Moon, so this reminder can't "
            + "be delivered. The routine is still here whenever you open the app.")
            .listRowBackground(PocketColor.background)
    }
    .scrollContentBackground(.hidden)
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
