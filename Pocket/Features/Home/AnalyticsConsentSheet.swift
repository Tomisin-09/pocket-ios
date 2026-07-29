import SwiftUI

/// The one-time **analytics consent ask** (ADR 0120).
///
/// Deliberately *not* part of the first-launch intake. Analytics exists to measure whether a cold
/// install reaches a first practice, and putting the ask in front of that flow would tax the very
/// thing it measures. So it surfaces once, after a first completed practice, when the player has
/// felt what the app does and the question can be answered on evidence rather than on trust.
///
/// **Opt-in, and honestly so.** `AppSettings.analyticsEnabled` defaults to `false`, so *every* exit
/// from this screen that isn't an explicit yes leaves analytics off — there is no dismissal path
/// that quietly grants consent. Declining is given the same weight as accepting: a consent screen
/// that nudges is worse than no consent screen, because it makes the privacy claim a lie.
///
/// The copy names what is and isn't collected in concrete terms rather than in the abstract. It is
/// the sentence the whole brand claim rests on, and it must survive being read carefully.
struct AnalyticsConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
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
            Text("Help make Red Moon better?")
                .font(.futura(.title2, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Entirely up to you, and easy to change later.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 18) {
            point(icon: "chart.bar",
                  title: "What we'd count",
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
    // Accept is the filled capsule and decline is plain text, matching the app's standing
    // primary/secondary grammar — but decline is a full-width, equally reachable target rather than
    // a buried "no thanks", and it is the outcome of every other exit from this screen too.

    private var buttons: some View {
        VStack(spacing: 6) {
            Button {
                analyticsEnabled = true
                haptic(.medium)
                dismiss()
            } label: {
                Text("Count me in")
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
                Text("No thanks")
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

#Preview {
    Color.clear
        .fullScreenCover(isPresented: .constant(true)) { AnalyticsConsentSheet() }
}
