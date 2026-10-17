import SwiftUI

/// **Home's free-week countdown** (ADR 0256 D1): *Your free week ends in 3 days · Manage*, while the
/// monthly's free week is set to turn into a payment.
///
/// 0144 D6's in-app half, brought back: it needs no permission and can't be denied, which is why it is
/// the reminder and a notification isn't. One tap opens Apple's subscriptions, where the week can be
/// cancelled. `PlanCountdown` decides when it shows and what it says. It draws nothing once the player
/// has cancelled, outside the week, and without a store.
struct FreeWeekCountdown: View {
    @Environment(PlanStore.self) private var plan: PlanStore?
    @State private var managing = false

    /// The line at `now`, or `nil` (`PlanCountdown`'s rule). Asked once before the timeline as well
    /// as inside it, so nobody without a countdown builds a view that ticks every minute. An empty
    /// view there would also take a slot in Home's stack, and leave a double gap under the greeting.
    private func line(at now: Date) -> String? {
        guard let plan, plan.inFreeWeek else { return nil }
        return PlanCountdown.line(freeSpan: plan.trialOffer?.span ?? "trial", endsAt: plan.monthlyPeriodEnd,
                                  renews: plan.ownMonthlyRenews, now: now, calendar: .current)
    }

    var body: some View {
        if line(at: .now) != nil {
            // Re-read each minute, so a Home left open across midnight doesn't keep yesterday's count.
            TimelineView(.everyMinute) { context in
                if let line = line(at: context.date) {
                    Button { managing = true } label: { row(line) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(line). Manage your subscription.")
                }
            }
            .background {
                SubscriptionManagement(isPresented: $managing, groupID: plan?.subscriptionGroupID)
            }
        }
    }

    private func row(_ line: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
            Text(line)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Spacer(minLength: 8)
            Text("Manage")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.practiceCardWash))
    }
}

#Preview("Free week — three days left") {
    FreeWeekCountdown()
        .padding(20)
        .environment(PlanStore(preview: .monthly,
                               prices: PlanStore.OfferPrices(monthly: "£1", payOnce: "£15",
                                                             trial: PlanTrial(unit: .week, value: 1)),
                               ownMonthlyRenews: true, freeWeekEnds: .now.addingTimeInterval(3 * 86_400)))
        .preferredColorScheme(.dark)
}
