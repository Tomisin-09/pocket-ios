import StoreKit
import SwiftUI

/// **"Trial ends in N days · Manage"** — the always-present half of ADR 0144 D6's trial reminder.
///
/// The local notification can be denied; this cannot. It needs no permission, so a player who said no
/// to notifications (or never saw the ask) still knows where they are in the trial, and is one tap
/// from Apple's manage-subscriptions sheet. That is the whole point of the commitment: a 30-day
/// annual-first trial is only defensible if it's hard to convert by accident.
///
/// Renders nothing when no trial is running — `TrialReminder.daysRemaining` returns `nil` — so both
/// hosts can include it unconditionally.
struct TrialCountdownRow: View {
    /// **Optional** on purpose: this row is embedded in Home and Settings, whose Xcode previews don't
    /// inject a `TrialReminder`, and a non-optional `@Environment(Observable.self)` traps when the
    /// value is missing. Absent reminder = no trial = nothing to draw, which is the right answer in a
    /// preview anyway.
    @Environment(TrialReminder.self) private var trialReminder: TrialReminder?
    @State private var showingManageSubscriptions = false

    /// Home sits on the app background and needs its own card; Settings is inside a `Form` row that
    /// already provides one.
    var style: Style = .card

    enum Style { case card, plain }

    var body: some View {
        if let days = trialReminder?.daysRemaining() {
            Button {
                showingManageSubscriptions = true
                haptic(.light)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .font(.futura(.footnote, weight: .semibold))
                        .foregroundStyle(PocketColor.practice)
                    Text("Trial ends in \(days) day\(days == 1 ? "" : "s")")
                        .font(.futura(.subheadline, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Spacer(minLength: 8)
                    Text("Manage")
                        .font(.futura(.subheadline, weight: .semibold))
                        .foregroundStyle(PocketColor.practice)
                }
                .padding(style == .card ? 14 : 0)
                .frame(maxWidth: .infinity)
                .background {
                    if style == .card {
                        RoundedRectangle(cornerRadius: 14).fill(PocketColor.practiceCardWash)
                    }
                }
            }
            .buttonStyle(.plain)
            .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
            .accessibilityLabel("Trial ends in \(days) day\(days == 1 ? "" : "s"). Manage subscription.")
        }
    }
}
