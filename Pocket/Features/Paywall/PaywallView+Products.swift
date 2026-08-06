import StoreKit
import SwiftUI

/// `PaywallView`'s **product half** — which products back the two plan cards, the live price and
/// trial copy read off them, and the purchase / restore actions. Split out of `PaywallView.swift` to
/// keep that file under the 400-line cap and the type within SwiftLint's `type_body_length`; the
/// screen's chrome and layout stay there.
///
/// Everything here answers one question: **what do the loaded products actually say?** ADR 0144 D5
/// made that the rule rather than a preference — the trial length lives in App Store Connect, so the
/// only honest paywall is one that reads it.
extension PaywallView {
    // MARK: - Pricing text (live, with a safe fallback before products load)

    var annualProduct: Product? {
        store.products.first { $0.id == StoreManager.ProductID.annual }
    }
    var monthlyProduct: Product? {
        store.products.first { $0.id == StoreManager.ProductID.monthly }
    }
    var selectedProduct: Product? {
        plan == .annual ? annualProduct : monthlyProduct
    }

    var annualPriceText: String {
        annualProduct.map { "\($0.displayPrice)/yr" } ?? "£49.99/yr"
    }
    var monthlyPriceText: String {
        monthlyProduct.map { "\($0.displayPrice)/mo" } ?? "£5.99/mo"
    }

    /// The per-month equivalent of the annual plan — the retention lever this category lives on.
    var annualCaption: String {
        guard let annual = annualProduct else { return "≈ £4.17/mo · best value" }
        let perMonth = annual.price / 12
        let formatted = perMonth.formatted(annual.priceFormatStyle)
        return "≈ \(formatted)/mo · best value"
    }

    // MARK: - Actions

    func load() async {
        await store.loadProducts()
        // Both, not just the annual one — the CTA has to be honest about whichever plan is selected.
        if let sub = annualProduct?.subscription {
            annualEligible = await sub.isEligibleForIntroOffer
        }
        if let sub = monthlyProduct?.subscription {
            monthlyEligible = await sub.isEligibleForIntroOffer
        }
    }

    func buy() async {
        guard let product = selectedProduct else { return }
        purchasing = true
        defer { purchasing = false }
        do {
            // Read *before* the purchase: a completed buy consumes the intro offer, so by the time
            // `purchase` returns, `isEligibleForIntroOffer` is already false for this account.
            let startedTrial = eligibleForTrial
            if try await store.purchase(product) {
                // Reported here rather than in `StoreManager` because trial eligibility is only
                // known on this screen (ADR 0120) — and trial-vs-outright is the interesting half.
                Analytics.send(.purchaseCompleted(product: plan == .annual ? .annual : .monthly,
                                                  trial: startedTrial))
                // The one moment the app can be certain a trial began (ADR 0144 D6) — StoreKit alone
                // can't say whether the current period is a trial without a deprecated `offerType`
                // read, so this is where the end date is recorded.
                if startedTrial {
                    trialReminder.noteTrialPurchase(expiration: store.currentExpiration,
                                                    willAutoRenew: store.willAutoRenew)
                }
                dismiss()
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        purchasing = true
        defer { purchasing = false }
        await store.restore()
        if store.isPro { dismiss() }
    }

    /// Whether the **selected** plan currently offers a free trial.
    var eligibleForTrial: Bool {
        trialPhrase != nil && (plan == .annual ? annualEligible : monthlyEligible)
    }

    /// The selected plan's trial length, in words, read live from the product (ADR 0144 D5) — e.g.
    /// `"1-month"`. `nil` when the product carries no introductory offer, or hasn't loaded: in both
    /// cases the paywall says nothing about a trial rather than guessing a number.
    var trialPhrase: String? {
        guard let period = selectedProduct?.subscription?.introductoryOffer?.period else { return nil }
        return TrialPeriodCopy.hyphenated(unit: Self.copyUnit(period.unit), value: period.value)
    }

    static func copyUnit(_ unit: Product.SubscriptionPeriod.Unit) -> TrialPeriodCopy.Unit {
        switch unit {
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .year: return .year
        @unknown default: return .day
        }
    }

}
