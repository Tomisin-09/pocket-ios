import SwiftUI

/// **Settings ▸ Red Moon Pro** (ADR 0162 D2) — entitlement state and the three things a player can do
/// about it: manage, upgrade, restore.
///
/// It sits **above** the Preferences group on the hub because it is *state* — what you have — rather
/// than a preference. On the flat screen it was thirteenth, below the exercise-animation toggle.
///
/// A subscriber manages or cancels through Apple's native sheet; there is no in-app billing UI (ADR
/// 0112). **Restore is always offered**, subscriber or not — App Review requires it, and one push
/// into Settings is where every other app puts it.
struct ProSettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    /// Presents Apple's native Manage-Subscriptions sheet (subscribers only — no in-app billing UI).
    @State private var showingManageSubscriptions = false

    var body: some View {
        Form {
            Section {
                // While a trial is running, say so before offering anything else (ADR 0144 D6).
                TrialCountdownRow(style: .plain)
                if isPro {
                    Button("Manage Subscription") { showingManageSubscriptions = true }
                } else {
                    Button("Upgrade to Red Moon Pro") { presentPaywall(.general) }
                }
                Button("Restore Purchases") { Task { await store.restore() } }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isPro
                         ? "You have Red Moon Pro. Manage or cancel anytime in Manage Subscription."
                         : "Unlock the full exercise catalog, “draw your own”, and Today's session.")
                    // TODO(beta): remove with the rest of the closed-beta grant.
                    // Closed-beta testers are granted Pro without a purchase, and that grant can only
                    // take effect in a build we cannot debug. This is the line we ask them to send.
                    Text(store.betaDiagnostic)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .settingsScreen(title: "Red Moon Pro")
        // Apple's native Manage-Subscriptions screen — the ADR 0112 "no in-app billing UI" contract.
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
    }
}

#Preview {
    NavigationStack { ProSettingsView() }
        .preferredColorScheme(.dark)
        .environment(StoreManager())
}
