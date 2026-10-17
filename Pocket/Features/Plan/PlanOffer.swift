import StoreKit
import SwiftUI

/// **The offer** (ADR 0256 D1, D3, D8): the promise, the two ways to pay, *Restore purchases*, the
/// renewal disclosure and the two links Guideline 3.1.2 asks for. The wall shows it, and so does
/// *Your plan* in Settings (D10), which is why it is its own view.
///
/// **Every amount is the product's own price**, written by `Product.planPrice`. Nothing here is a
/// price literal, so an American player reads $1 and the copy can't disagree with the price sheet. Until both products
/// load there is no promise and no button: a button that can't buy anything would be the one
/// broken control on the screen.
struct PlanOffer: View {
    /// `false` on *Your plan* while the monthly is already running: the only thing left to offer
    /// is Pay once.
    var offersMonthly = true
    let onPayOnceOverRenewal: () -> Void

    @Environment(PlanStore.self) private var plan: PlanStore?
    @Environment(\.purchase) private var purchase

    /// The product being bought, so its button shows progress and neither can be tapped twice.
    @State private var buying: String?
    @State private var restoring = false
    @State private var confirmingPayOnce = false
    @State private var notice: Notice?

    /// One alert, for the four things a purchase or a restore can need to say.
    private enum Notice: Identifiable {
        case pending, failed(String), nothingToRestore

        var id: String {
            switch self {
            case .pending: "pending"
            case .failed(let text): "failed-\(text)"
            case .nothingToRestore: "nothingToRestore"
            }
        }

        var title: String {
            switch self {
            case .pending: "Waiting for approval"
            case .failed: "Couldn’t complete the purchase"
            case .nothingToRestore: "Nothing to restore"
            }
        }

        var message: String {
            switch self {
            case .pending:
                "The purchase needs approving first, perhaps through Ask to Buy. The plan opens as soon as "
                    + "it is approved."
            case .failed(let text): text
            case .nothingToRestore:
                "This Apple Account hasn’t bought Red Moon’s plan. If you bought it with another one, sign "
                    + "in with that account and try again."
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let prices = plan?.offerPrices {
                // The free week belongs to the monthly button, so it goes wherever that button goes.
                let trial = offersMonthly ? prices.trial : nil
                promise(monthly: prices.monthly, payOnce: prices.payOnce)
                if offersMonthly {
                    let monthly = PlanWallCopy.monthlyOption(monthly: prices.monthly, trial: trial)
                    option(PlanProduct.monthly, title: monthly.title, detail: monthly.detail)
                }
                option(PlanProduct.payOnce, title: "Pay once · \(prices.payOnce)",
                       detail: "One payment. It never renews.")
                Text(PlanWallCopy.renewalDisclosure(monthly: prices.monthly, trial: trial))
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            } else if plan == nil || plan?.productsUnavailable == true {
                unavailable
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            restoreButton
            legalLinks
        }
        .task { await plan?.loadProducts() }
        .alert(PlanWallCopy.renewingWarningTitle, isPresented: $confirmingPayOnce) {
            Button("Pay once") { buy(PlanProduct.payOnce, confirmed: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(PlanWallCopy.renewingWarning)
        }
        .alert(notice?.title ?? "", isPresented: Binding(get: { notice != nil },
                                                         set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notice?.message ?? "")
        }
    }

    // MARK: - Parts

    /// D8, verbatim beneath its first line.
    private func promise(monthly: String, payOnce: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(PlanWallCopy.promise(monthly: monthly, payOnce: payOnce))
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text(PlanWallCopy.promiseLine)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCardWash))
        .accessibilityElement(children: .combine)
    }

    private func option(_ productID: String, title: String, detail: String) -> some View {
        Button { buy(productID) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.futura(.headline))
                    Text(detail)
                        .font(.futura(.subheadline))
                        .opacity(0.85)
                }
                Spacer(minLength: 8)
                if buying == productID {
                    ProgressView().tint(PocketColor.background)
                }
            }
            .foregroundStyle(PocketColor.background)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCTA))
        }
        .buttonStyle(.plain)
        .disabled(buying != nil || restoring)
        .accessibilityIdentifier("plan.buy.\(productID)")
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couldn’t reach the App Store")
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text("The plan’s prices didn’t load. Check your connection and try again.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            Button("Try again") { Task { await plan?.loadProducts() } }
                .font(.futura(.subheadline, weight: .semibold))
                .tint(PocketColor.practice)
        }
    }

    private var restoreButton: some View {
        Button {
            Task {
                restoring = true
                defer { restoring = false }
                if await plan?.restore() != true { notice = .nothingToRestore }
            }
        } label: {
            HStack(spacing: 8) {
                Text("Restore purchases")
                if restoring { ProgressView() }
            }
            .font(.futura(.subheadline, weight: .semibold))
        }
        .tint(PocketColor.practice)
        .disabled(buying != nil || restoring)
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("Terms of Use", destination: AboutSection.appleStandardEULA)
            Link("Privacy Policy", destination: AboutSection.privacyPolicy)
        }
        .font(.futura(.footnote))
        .tint(PocketColor.textSecondary)
    }

    // MARK: - Buying

    /// Buy a product. Pay once while the player's own monthly renews asks first (D5 step 1), and
    /// afterwards hands over to Apple's manage sheet (step 2). The product is looked up at the tap, so
    /// a preview's offer, which has prices and no products, draws everything and buys nothing.
    private func buy(_ productID: String, confirmed: Bool = false) {
        guard let product = plan?.products[productID] else { return }
        let overRenewal = productID == PlanProduct.payOnce && plan?.ownMonthlyRenews == true
        if overRenewal && !confirmed {
            confirmingPayOnce = true
            return
        }
        Task {
            buying = product.id
            defer { buying = nil }
            do {
                let result = try await purchase(product)
                guard let plan else { return }
                switch await plan.complete(result) {
                case .bought: if overRenewal { onPayOnceOverRenewal() }
                case .cancelled: break
                case .pending: notice = .pending
                case .failed(let text): notice = .failed(text)
                }
            } catch {
                notice = .failed(error.localizedDescription)
            }
        }
    }
}
