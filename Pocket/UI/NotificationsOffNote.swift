import SwiftUI

/// **"Notifications are off, and here is the only way back"** (ADR 0186 D5).
///
/// Shown beside a reminder control the player has switched **on** while the app has no permission to
/// deliver it. Two features raise it — the paywall's trial reminder and a routine's practice
/// reminder — which is why it is one view rather than a paragraph copied into each.
///
/// **It is an inline note, not an alert.** `MicAccessAlert` is an alert because it answers a gesture
/// that was *refused*: the swipe did nothing, so something has to say why, once. This answers a
/// control that *worked* — the intent is recorded and stays recorded — and only reports a standing
/// condition alongside it. An alert for that would interrupt to deliver news the player can act on
/// whenever they like, and would fire again on every re-entry to the screen.
///
/// The Settings app is offered because it is genuinely the only route: the system prompt is
/// one-shot for the whole app, and after a denial there is no API to present it again.
struct NotificationsOffNote: View {
    /// What is not being delivered, and what still works without it. Per-feature, because "the trial
    /// countdown still shows in the app" and "the routine is still here" are different reassurances.
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(PocketColor.practice)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    NotificationsOffNote(message: "Notifications are off for Red Moon, so this reminder can't be "
        + "delivered. The trial countdown still shows in the app.")
        .padding()
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
