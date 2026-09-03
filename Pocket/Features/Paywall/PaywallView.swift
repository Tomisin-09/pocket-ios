import StoreKit
import SwiftUI

/// The Red Moon Pro paywall (ADR 0112). One screen, presented by the shared `.presentPaywall` action.
/// On-brand (crescent seal · Futura · design tokens, theme-aware) but a **conversion** surface first:
/// a contextual headline, three value lines, **Annual pre-selected** over Monthly, one primary CTA,
/// Restore, and the App-Review-required disclosure block (auto-renew · price · cancel anytime) with
/// Terms + Privacy links. Prices and trial-eligibility come live from StoreKit via `StoreManager`.
struct PaywallView: View {
    let trigger: PaywallTrigger

    // Non-private (like the `@State`s below) so the `PaywallView+Products` extension — a separate
    // file, for the 400-line cap — can read the store, the selected plan and the purchase flags.
    @Environment(StoreManager.self) var store
    @Environment(TrialReminder.self) var trialReminder
    @Environment(\.dismiss) var dismiss

    enum Plan { case annual, monthly }
    @State var plan: Plan = .annual
    /// Intro-offer eligibility, **per product** (ADR 0144 D5). Read for the *selected* plan: the two
    /// can differ (eligibility is one-shot per subscription *group*, but a product can also simply
    /// carry no offer), and reading only the annual one is how the CTA ends up promising a trial the
    /// monthly purchase won't give. Optimistic defaults so the CTA doesn't flicker "Subscribe" →
    /// "Start … free trial" while products load.
    @State var annualEligible = true
    @State var monthlyEligible = true
    @State var purchasing = false
    @State var purchaseError: String?
    /// Notification permission as of the last time this screen looked (ADR 0186 D5). `nil` until
    /// read. Re-read in `load()` rather than cached across presentations, because the player can
    /// change it in the Settings app while the app is backgrounded and come back to a stale answer.
    @State var notificationPermission: NotificationPermission?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                valueProps
                plans
                reminderOptIn
                cta
                disclosure
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .task { await load() }
        .alert("Purchase failed", isPresented: showingError) {
            Button("OK", role: .cancel) { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Header

    /// The brand lockup, then the contextual line. The wordmark is **artwork, not text**: it carries
    /// the "PRO" weighting the designer set, which set type can't reproduce, and it replaces both the
    /// crescent seal and the "Red Moon Pro" title that used to sit here (the crescent still leads
    /// Settings, the artist-name prompt and the app icon). It therefore needs an explicit
    /// accessibility label — nothing else on this screen announces the product's name.
    ///
    /// The top padding clears the top-trailing ✕: the wordmark is ~7:1 and runs nearly the full
    /// content width, so unlike the 64 pt seal it reaches under the close button unless pushed down.
    private var header: some View {
        VStack(spacing: 14) {
            Image("RedMoonProWordmark")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280)
                .accessibilityLabel("Red Moon Pro")
            Text(trigger.headline)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Value props

    /// Three claims, in the order they earn a subscription. **Loops lead** — playing along to your
    /// own tracks is the thing Red Moon does that a free metronome app doesn't, and it is what the
    /// App Store listing opens on too ("Loop and slow down"); the wording and the `repeat` glyph are
    /// deliberately the same as the Practice library's Loops row, so the pitch and the app agree.
    /// The catalog is second because it's the volume claim, and the planner third because it only
    /// means anything once you have material to plan with.
    private var valueProps: some View {
        VStack(alignment: .leading, spacing: 16) {
            valueRow("repeat", "Loop and slow down",
                     "Loop the tricky bar of your own tracks and slow it down — the pitch stays true.")
            valueRow("square.grid.3x3.fill", "The full exercise catalog",
                     "Every scale, chord, arpeggio and technique drill — no limits.")
            valueRow("sparkles", "Today's session",
                     "A fresh, self-guided practice plan built from your goals.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.practice)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.futura(.body, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(subtitle)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    // MARK: - Plans

    private var plans: some View {
        VStack(spacing: 12) {
            planCard(.annual, title: "Annual", price: annualPriceText,
                     caption: annualCaption, badge: "Best value")
            planCard(.monthly, title: "Monthly", price: monthlyPriceText,
                     caption: "Billed monthly", badge: nil)
        }
    }

    private func planCard(_ candidate: Plan, title: String, price: String,
                          caption: String, badge: String?) -> some View {
        let selected = plan == candidate
        return Button {
            plan = candidate
            haptic(.light)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.futura(.title3))
                    .foregroundStyle(selected ? PocketColor.practice : PocketColor.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.futura(.body, weight: .semibold))
                            .foregroundStyle(PocketColor.textPrimary)
                        if let badge { bestValueBadge(badge) }
                    }
                    Text(caption)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Text(price)
                    .font(.futura(.body, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? PocketColor.practice.opacity(0.12) : PocketColor.surfaceStandard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? PocketColor.practice : PocketColor.surfaceBorder,
                            lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func bestValueBadge(_ text: String) -> some View {
        Text(text)
            .font(.futura(.caption2, weight: .bold))
            .foregroundStyle(PocketColor.background)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(PocketColor.practice))
    }

    // MARK: - Trial reminder opt-in (ADR 0144 D6)

    /// "Remind me before the trial ends", shown only when a trial is actually on offer. Permission is
    /// requested **here, before the purchase**: at this point it is part of the offer being weighed
    /// and reads as something the player asked for. Requested after the buy, the same prompt reads as
    /// marketing and is denied once, permanently.
    @ViewBuilder
    private var reminderOptIn: some View {
        if eligibleForTrial {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: reminderBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remind me before the trial ends")
                            .font(.futura(.subheadline, weight: .semibold))
                            .foregroundStyle(PocketColor.textPrimary)
                        Text("A single notification, 24 hours before you'd be charged.")
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                .tint(PocketColor.practice)

                if trialReminder.remindersEnabled, notificationPermission == .denied {
                    NotificationsOffNote(
                        message: "Notifications are off for Red Moon, so this reminder can't be "
                            + "delivered. The trial countdown still shows in the app.")
                }
            }
        }
    }

    /// Turning the toggle on records the intent and asks for permission **only if the prompt is
    /// still available** (ADR 0186 D5).
    ///
    /// It used to assign the authorization result straight back into `remindersEnabled`, so on a
    /// *remembered* denial — the prompt is one-shot for the whole app, and any other feature may
    /// have spent it — the toggle flipped visibly back off with nothing said. That looked like the
    /// control breaking. Now the intent sticks and the blocker is named, with a route to fix it.
    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { trialReminder.remindersEnabled },
            set: { wants in
                guard wants else {
                    trialReminder.remindersEnabled = false
                    return
                }
                Task { notificationPermission = await trialReminder.requestAuthorization() }
            })
    }

    // MARK: - CTA

    private var cta: some View {
        VStack(spacing: 12) {
            Button { Task { await buy() } } label: {
                Group {
                    if purchasing {
                        ProgressView().tint(PocketColor.background)
                    } else {
                        Text(ctaTitle)
                            .font(.futura(.headline))
                            .foregroundStyle(PocketColor.background)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCTA))
            }
            .buttonStyle(.plain)
            .disabled(purchasing || selectedProduct == nil)

            Button("Restore Purchases") { Task { await restore() } }
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.practice)
                .disabled(purchasing)

            // The launch wall (ADR 0144 D4) comes to the player rather than being walked into, so it
            // needs a dismissal that reads as one. The corner ✕ alone is too quiet for a full-screen
            // cover — and an unmistakable way out is also what keeps App Review 3.1.2 comfortable.
            if trigger == .launch {
                Button("Not now") { dismiss() }
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .disabled(purchasing)
            }
        }
    }

    private var ctaTitle: String {
        guard eligibleForTrial, let trialPhrase else { return "Subscribe" }
        return "Start \(trialPhrase) free trial"
    }

    // MARK: - Disclosure (App Review requires this block)

    private var disclosure: some View {
        VStack(spacing: 10) {
            Text(disclosureText)
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Terms of Use", destination: Self.termsURL)
                Text("·").foregroundStyle(PocketColor.textSecondary)
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.futura(.caption2, weight: .semibold))
            .tint(PocketColor.practice)
        }
        .padding(.top, 4)
    }

    private var disclosureText: String {
        "Red Moon Pro is an auto-renewing subscription. "
        + (eligibleForTrial && trialPhrase != nil
           ? "Your \(trialPhrase ?? "") free trial converts to the selected plan unless cancelled at "
             + "least 24 hours before it ends. "
           : "")
        + "Payment is charged to your Apple Account at confirmation. It renews automatically unless "
        + "turned off at least 24 hours before the period ends. Manage or cancel anytime in Settings."
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.futura(.title2))
                .foregroundStyle(PocketColor.textSecondary)
                .padding(16)
        }
        .accessibilityLabel("Close")
    }

    private var showingError: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    /// Apple's standard EULA — the licence that governs the app when we ship no custom terms; the
    /// "Terms of Use (EULA)" disclosure Apple requires once auto-renewable subscriptions ship. Mirrors
    /// the link in Settings.
    private static let termsURL =
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL =
        URL(string: "https://decooperations.co.uk/privacy#red-moon-practice")!
}

#Preview("Paywall — draw your own") {
    PaywallView(trigger: .drawYourOwn)
        .environment(StoreManager())
        // `notifications: nil` — a preview must not reach for the real notification centre.
        .environment(TrialReminder(usesSystemNotifications: false))
}

#Preview("Paywall — launch wall") {
    PaywallView(trigger: .launch)
        .environment(StoreManager())
        .environment(TrialReminder(usesSystemNotifications: false))
}
