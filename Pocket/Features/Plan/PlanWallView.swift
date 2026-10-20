import SwiftUI

/// **The wall** (ADR 0256 D3): what a gated screen draws while the plan is off.
///
/// It is titled with the door the player tapped, says in one sentence what is free and what the
/// plan adds, and then makes the offer. A returning player reads *"Everything you made is still
/// here."* first (D4), because the first thing a lapsed player fears is that it has gone.
struct PlanWallView: View {
    let door: PlanDoor
    /// After Pay once over a renewing monthly (D5 step 2). The host presents Apple's manage sheet,
    /// because this view is replaced by the screen it guards the moment the purchase lands.
    let onPayOnceOverRenewal: () -> Void

    @Environment(PlanStore.self) private var plan: PlanStore?

    private var returning: Bool {
        PlanAccess.greetsReturningPlayer(access: plan?.access ?? .none,
                                         hasBoughtBefore: plan?.hasBoughtBefore ?? false)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(PlanWallCopy.headline(returning: returning))
                        .font(.futura(.title, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                        .accessibilityIdentifier(UITestHooks.planWallHeadline)
                    Text(PlanWallCopy.explanation(returning: returning))
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                PlanOffer(onPayOnceOverRenewal: onPayOnceOverRenewal)
            }
            // Full width, leading: a short state (Pay once is one line) would otherwise shrink to its
            // text and sit centred in the scroll.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .readableWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(door.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Wall — first time") {
    NavigationStack { PlanWallView(door: .practice) {} }
        .environment(PlanStore(preview: .none,
                               prices: PlanStore.OfferPrices(monthly: "£1", payOnce: "£15",
                                                             trial: PlanTrial(unit: .week, value: 1))))
        .preferredColorScheme(.dark)
}

#Preview("Wall — free week already used") {
    NavigationStack { PlanWallView(door: .routine) {} }
        .environment(PlanStore(preview: .none, prices: PlanStore.OfferPrices(monthly: "£1", payOnce: "£15")))
        .preferredColorScheme(.dark)
}

#Preview("Wall — App Store unreachable") {
    NavigationStack { PlanWallView(door: .earTraining) {} }
        .environment(PlanStore(preview: .none))
        .preferredColorScheme(.dark)
}
