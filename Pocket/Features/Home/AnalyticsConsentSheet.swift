import SwiftUI

/// The one-time analytics screen — **two roles in one file**, chosen by region (ADR 0120, split by
/// ADR 0147).
///
/// **`.ask` — EEA + CH.** The ADR 0120 consent ask, verbatim and unchanged. Deliberately *not* part
/// of the first-launch intake: analytics exists to measure whether a cold install reaches a first
/// practice, and putting the ask in front of that flow would tax the very thing it measures. So it
/// surfaces once, after a first practice, when the player has felt what the app does and the
/// question can be answered on evidence rather than on trust.
///
/// **`.notify` — UK + rest of world, and only as a catch-up.** Under DUAA 2025 Sch A1 para 5 the
/// default is on, and a fresh install is told by the footnote in `ArtistIntakeView` — so this role
/// exists purely for installs that passed through an intake predating that footnote. It states
/// rather than asks, and offers turning it off as an equal option. **It is transitional:** once no
/// such install remains it is dead code and should be deleted, not kept as furniture.
///
/// **The anti-nudge rule binds harder here, not less.** Under `.ask` a nudge costs a data point;
/// under `.notify`, where the default is already on, a nudge is the difference between informing
/// somebody and processing them without their noticing. So the secondary action is a full-width,
/// equally reachable target in both modes — never a buried "no thanks".
///
/// The copy names what is and isn't collected in concrete terms rather than in the abstract. It is
/// the sentence the whole brand claim rests on, and it must survive being read carefully.
struct AnalyticsConsentSheet: View {
    /// Which role this presentation plays. Supplied by the caller from
    /// `AnalyticsPolicy.consentModel(regionCode:)` rather than read here, so the view stays
    /// previewable in both modes.
    let mode: AnalyticsPolicy.ConsentModel

    @Environment(\.dismiss) private var dismiss
    /// The `= false` is unreachable in practice: `AppSettings.seedAnalyticsDefaultIfNeeded` writes
    /// the key at launch, so it is always present by the time this screen can appear (ADR 0147 §3).
    /// Kept as a safe-direction backstop, not as the policy.
    @AppStorage(AppSettings.Key.analyticsEnabled) private var analyticsEnabled = false

    var body: some View {
        ZStack {
            PocketColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                headline
                explanation
                Spacer(minLength: 0)
                buttons
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .readableWidth()
        }
    }

    // MARK: - Copy

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .ask
                 ? "Help make Red Moon better?"
                 : "Red Moon counts which features get used")
                .font(.futura(.title2, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(mode == .ask
                 ? "Entirely up to you, and easy to change later."
                 : "Never your playing — and you can turn it off right here.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Same three points in both modes; only the tense moves, because under `.notify` this
            // describes what is already happening rather than what would happen.
            point(icon: "chart.bar",
                  title: mode == .ask ? "What we'd count" : "What we count",
                  body: "Which features get used — how often a loop gets made, which exercises "
                      + "get built, where the app gets in your way.")
            point(icon: "eye.slash",
                  title: "What never leaves this device",
                  body: "Your playing. Your recordings, your notes, your song names, your artist "
                      + "name — none of it is ever sent anywhere.")
            point(icon: "person.crop.circle.badge.questionmark",
                  title: "Nothing that identifies you",
                  body: "No account, no advertising ID, no profile. The counts can't be traced "
                      + "back to you, or joined up across sessions.")
        }
        .padding(.top, 28)
    }

    private func point(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.practice)
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(body)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Choice
    //
    // Accept is the filled capsule and the other option is plain text, matching the app's standing
    // primary/secondary grammar — but that option is a full-width, equally reachable target rather
    // than a buried "no thanks".
    //
    // The two modes differ only in what the primary *means*. Under `.ask` it grants consent and the
    // secondary is the outcome of every other exit from the screen. Under `.notify` the primary
    // merely acknowledges (the value is already on), and the secondary is the "simple, free means of
    // objecting" the DUAA exception is conditional on — so it must write `false`, not just dismiss.

    private var buttons: some View {
        VStack(spacing: 6) {
            Button {
                // `.notify` deliberately does **not** write `true` here: the seeded default already
                // holds it, and writing on acknowledgement would overwrite a player who had turned
                // it off in Settings before this catch-up ever appeared.
                if mode == .ask { analyticsEnabled = true }
                haptic(.medium)
                dismiss()
            } label: {
                Text(mode == .ask ? "Count me in" : "Got it")
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(PocketColor.practice, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                analyticsEnabled = false
                haptic(.light)
                dismiss()
            } label: {
                Text(mode == .ask ? "No thanks" : "Turn this off")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.plain)

            Text("You can change this any time in Settings.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.top, 24)
    }
}

#Preview("Ask — EEA") {
    Color.clear
        .fullScreenCover(isPresented: .constant(true)) { AnalyticsConsentSheet(mode: .ask) }
}

#Preview("Notify — UK catch-up") {
    Color.clear
        .fullScreenCover(isPresented: .constant(true)) { AnalyticsConsentSheet(mode: .notify) }
}
