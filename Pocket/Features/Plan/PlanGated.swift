import StoreKit
import SwiftUI

/// **A screen behind the plan** (ADR 0256 D3). The gated screen wraps its own body in this, so
/// every route to it meets the same wall: a Home tile, a song's link, a reminder's tap, a shared
/// file, and any door added later that nobody remembered to gate. Its callers don't change.
///
/// Without the plan it draws the wall **in place of** the screen, and builds nothing behind it: the
/// content closure is never called, so no audio starts, no task runs and no row is written. With the
/// plan, it is the screen and nothing else. A purchase swaps one for the other where the player
/// stands, so they arrive where they were going (D3).
///
/// **It also outlives the wall**, which is why Apple's manage sheet hangs here rather than on the
/// wall: after Pay once over a renewing monthly (D5 step 2) the wall is already gone, replaced by
/// the screen it was guarding, and only this view is left to present from.
struct PlanGated<Content: View>: View {
    /// How the gated screen was reached, which decides what frames its wall.
    enum Presentation {
        /// Pushed, or the root of a cover the caller already gave a navigation bar: the wall uses
        /// the bar that is there.
        case pushed
        /// The root of a sheet: the wall brings its own bar, with *Not now*.
        case modal
    }

    let door: PlanDoor
    let presentation: Presentation
    let content: () -> Content

    @Environment(PlanStore.self) private var plan: PlanStore?
    @Environment(\.dismiss) private var dismiss
    @State private var managingSubscriptions = false

    init(_ door: PlanDoor, presentation: Presentation = .pushed,
         @ViewBuilder content: @escaping () -> Content) {
        self.door = door
        self.presentation = presentation
        self.content = content
    }

    var body: some View {
        Group {
            if plan.planIsOn {
                content()
            } else if plan?.hasResolved == false {
                // StoreKit hasn't answered yet: a paying player must not meet the wall in that moment.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PocketColor.background.ignoresSafeArea())
            } else {
                wall
            }
        }
        .background {
            SubscriptionManagement(isPresented: $managingSubscriptions, groupID: plan?.subscriptionGroupID)
        }
    }

    @ViewBuilder private var wall: some View {
        switch presentation {
        case .pushed:
            PlanWallView(door: door) { managingSubscriptions = true }
        case .modal:
            NavigationStack {
                PlanWallView(door: door) { managingSubscriptions = true }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Not now") { dismiss() }
                        }
                    }
            }
        }
    }
}

/// Apple's subscription management (D5), presented from a view of its own.
///
/// The group id arrives after launch, read off a transaction or the monthly product. Choosing the
/// sheet by `if let` on the gated screen itself would swap that screen's identity the moment the id
/// landed, and throw away whatever the player had typed into it. Down here the swap costs nothing.
struct SubscriptionManagement: View {
    @Binding var isPresented: Bool
    let groupID: String?

    var body: some View {
        if let groupID {
            Color.clear.manageSubscriptionsSheet(isPresented: $isPresented, subscriptionGroupID: groupID)
        } else {
            Color.clear.manageSubscriptionsSheet(isPresented: $isPresented)
        }
    }
}

/// The small lock a gated door draws while the plan is off (D3: locked, not hidden). VoiceOver
/// hears it as the door's **value**, never its label: the labels are the UI tests' contract
/// (ADR 0102 §1), and the tests run on the plan, where no lock is drawn.
struct PlanLockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(PocketColor.textSecondary)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Says a door is locked to VoiceOver, as a value, and only while it is (`PlanLockBadge`).
    func planLockedValue(_ locked: Bool) -> some View {
        accessibilityValue(locked ? "Needs the plan" : "")
    }
}
