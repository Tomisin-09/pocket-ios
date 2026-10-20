import StoreKit
import SwiftUI

/// **Settings ▸ Your plan** (ADR 0256 D10): which way the player pays, and what they can do about it.
///
/// - **Free:** the offer, as the wall makes it.
/// - **Monthly:** Apple's subscription management, and Pay once as the way off the monthly.
/// - **Pay once:** a line saying it is done, and, while the monthly still renews beside it, the way to
///   stop it and to ask Apple about the month that overlapped (D5 steps 3 and 4).
///
/// A scroll rather than a `Form`, because the offer is the wall's own view (`PlanOffer`) and a form
/// would draw each of its parts as a separate row.
struct YourPlanSettingsView: View {
    @Environment(PlanStore.self) private var plan: PlanStore?
    @State private var managingSubscriptions = false
    @State private var requestingRefund = false

    private var access: PlanAccess { plan?.access ?? PlanStore.accessWithoutStore }

    private var overlaps: Bool {
        PlanAccess.offersCancelMonthly(access: access, ownMonthlyRenews: plan?.ownMonthlyRenews ?? false)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                status
                switch access {
                case .none:
                    PlanOffer { managingSubscriptions = true }
                case .monthly:
                    manageButton("Manage your subscription")
                    // Once the monthly won't renew, there is nothing left for Pay once to stop.
                    Text(plan?.ownMonthlyRenews == false
                         ? "Or pay once, and keep the plan for good."
                         : "Or pay once, and the monthly can stop.")
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                    PlanOffer(offersMonthly: false) { managingSubscriptions = true }
                case .payOnce:
                    if overlaps { overlap }
                }
            }
            // Full width, leading: a short state (Pay once is one line) would otherwise shrink to its
            // text and sit centred in the scroll.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .readableWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Your plan")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SubscriptionManagement(isPresented: $managingSubscriptions, groupID: plan?.subscriptionGroupID)
        }
        .background { refundRequest }
        .task { await plan?.refresh() }
    }

    // MARK: - Parts

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(access.summary)
                .font(.futura(.title, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(statusLine)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusLine: String {
        switch access {
        case .none:
            "Your songs and loops, the Metronome, your Journal and the Toolkit are free for good. The plan is "
                + "for practising: drills, routines, Today's session and the loop trainer."
        case .monthly:
            PlanWallCopy.monthlyStatus(
                endsOn: plan?.monthlyPeriodEnd?.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                freeSpan: plan?.inFreeWeek == true ? plan?.trialOffer?.span ?? "trial" : nil,
                renews: plan?.ownMonthlyRenews ?? true,
                monthly: plan?.offerPrices?.monthly)
        case .payOnce:
            "You've paid once. Nothing renews, and everything in Red Moon is open for good."
        }
    }

    /// D5 steps 3 and 4: Pay once is owned and the player's own monthly still renews.
    private var overlap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your monthly plan is still renewing")
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text("You've paid once, so the monthly isn't needed any more. Red Moon can't cancel it for you, "
                 + "but your Apple Account's subscriptions can.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            manageButton("Cancel your monthly plan")
            if plan?.latestMonthlyTransactionID != nil {
                Button("Ask Apple for a refund") { requestingRefund = true }
                    .font(.futura(.subheadline, weight: .semibold))
                    .tint(PocketColor.practice)
                Text("For the month that overlapped. Apple decides refunds, not Red Moon.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    private func manageButton(_ title: String) -> some View {
        Button { managingSubscriptions = true } label: {
            Text(title)
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.background)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCTA))
        }
        .buttonStyle(.plain)
    }

    /// Apple's refund sheet needs a transaction id it can't be given until one is known, so, like the
    /// manage sheet, it hangs off a view of its own.
    @ViewBuilder private var refundRequest: some View {
        if let transactionID = plan?.latestMonthlyTransactionID {
            Color.clear.refundRequestSheet(for: transactionID, isPresented: $requestingRefund)
        }
    }
}

#Preview("Your plan — free") {
    NavigationStack { YourPlanSettingsView() }
        .environment(PlanStore(preview: .none,
                               prices: PlanStore.OfferPrices(monthly: "£1", payOnce: "£15",
                                                             trial: PlanTrial(unit: .week, value: 1))))
        .preferredColorScheme(.dark)
}

#Preview("Your plan — the free week") {
    NavigationStack { YourPlanSettingsView() }
        .environment(PlanStore(preview: .monthly,
                               prices: PlanStore.OfferPrices(monthly: "£1", payOnce: "£15",
                                                             trial: PlanTrial(unit: .week, value: 1)),
                               ownMonthlyRenews: true, freeWeekEnds: .now.addingTimeInterval(5 * 86_400)))
        .preferredColorScheme(.dark)
}

#Preview("Your plan — Pay once") {
    NavigationStack { YourPlanSettingsView() }
        .environment(PlanStore(preview: .payOnce))
        .preferredColorScheme(.dark)
}

#Preview("Your plan — paid once, monthly still renewing") {
    NavigationStack { YourPlanSettingsView() }
        .environment(PlanStore(preview: .payOnce, ownMonthlyRenews: true))
        .preferredColorScheme(.dark)
}
