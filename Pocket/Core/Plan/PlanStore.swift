import Foundation
import Observation
import StoreKit

/// The **one** type that talks to the App Store about Red Moon's plan (ADR 0256 D9).
///
/// It reads `Transaction.currentEntitlements`, listens to `Transaction.updates` for the life of the
/// app, and refreshes whenever the app comes back to the foreground. That last one is the 2026-08
/// sandbox lesson: a plain expiry mints no transaction, so `updates` never hears about it, and a
/// lapsed monthly stayed open until a cold launch.
///
/// **It decides nothing.** Each verified transaction becomes an `OwnedPurchase`, and `PlanAccess`
/// says what the list opens. Nothing about the plan is stored: a lapse closes the doors and a
/// purchase opens them, read live, with no migration.
@MainActor
@Observable
final class PlanStore {

    /// What the player can open. Every gate reads `access.isOn` (D3).
    private(set) var access: PlanAccess
    /// Whether StoreKit has answered once. `access` starts at `.none` and the first read is async,
    /// so before this flips there is no telling "no plan" from "not asked yet". A paying player must
    /// not meet a lock or a wall in that moment, so until then a gate waits and no lock draws.
    private(set) var hasResolved: Bool
    /// Whether this Apple Account has bought the plan before (D4: the wall's returning headline).
    private(set) var hasBoughtBefore = false
    /// Whether the player's **own** monthly will renew again (D5). A family-shared monthly isn't
    /// theirs to cancel, so it never counts.
    private(set) var ownMonthlyRenews = false
    /// The monthly's subscription group, for Apple's manage sheet (D5 step 2). Read off the monthly
    /// product or transaction, because App Store Connect assigns it.
    private(set) var subscriptionGroupID: String?
    /// The monthly's latest payment, for *Ask Apple for a refund* on the overlapping month (D5 step 4).
    /// `nil` during the free week, which has nothing to refund.
    private(set) var latestMonthlyTransactionID: Transaction.ID?
    /// The last day of the player's own monthly period, for *Your plan*'s status line (D10).
    private(set) var monthlyPeriodEnd: Date?
    /// Whether the player's own monthly is in its free week (D1). Read from the transaction's `offer`,
    /// which is iOS 17.2 or later; before that it stays `false` and the week reads as a paid month.
    private(set) var inFreeWeek = false
    /// Whether this Apple Account can still have the free week (D1). Read again on every refresh,
    /// because buying the monthly uses it up.
    private(set) var trialEligible = false

    /// The two products, by id. Empty until `loadProducts()` lands.
    private(set) var products: [String: Product] = [:]
    /// Whether the last load failed to return both products. The wall says so, and offers a retry,
    /// rather than drawing a button that can't work (D3).
    private(set) var productsUnavailable = false

    /// The two prices as the offer writes them, for a preview that has no App Store to ask.
    private let previewPrices: OfferPrices?

    /// `false` for a preview's store and a UI test's override: neither touches StoreKit's entitlements.
    private let readsEntitlements: Bool
    /// `false` only for a preview's store, which has no App Store to ask.
    private let loadsProducts: Bool

    init() {
        #if DEBUG
        // Under `-uiTesting` the plan is fixed by the launch (D9), so a test drives the same app on
        // every run. Products still load, so the wall under `-plan free` draws what it really draws.
        if let forced = UITestRuntime.planOverride {
            access = forced
            hasResolved = true
            previewPrices = nil
            readsEntitlements = false
            loadsProducts = true
            return
        }
        #endif
        access = .none
        hasResolved = false
        previewPrices = nil
        readsEntitlements = true
        loadsProducts = true
        // The stream outlives every screen: the store is created once, at the app root.
        Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    /// A store that never asks the App Store, for previews of the wall and of a gated screen. Give it
    /// `prices` to see the offer as a player does; without them it draws the state where the products
    /// didn't load. `ownMonthlyRenews` with `.payOnce` is the overlap D5 is about, and `freeWeekEnds`
    /// with `.monthly` is the free week (D1).
    init(preview access: PlanAccess, prices: OfferPrices? = nil, ownMonthlyRenews: Bool = false,
         freeWeekEnds: Date? = nil) {
        self.access = access
        self.ownMonthlyRenews = ownMonthlyRenews
        monthlyPeriodEnd = freeWeekEnds
        inFreeWeek = freeWeekEnds != nil
        hasResolved = true
        previewPrices = prices
        readsEntitlements = false
        loadsProducts = false
    }

    // MARK: - Reading

    /// Re-read what the player owns. Safe at any moment: launch, foreground, after a purchase or a
    /// restore, and on every transaction update.
    func refresh() async {
        guard readsEntitlements else { return }
        var owned: [OwnedPurchase] = []
        var renews = false
        var groupID: String?
        var monthlyID: Transaction.ID?
        var periodEnd: Date?
        var freeWeek = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  PlanProduct.all.contains(transaction.productID) else { continue }
            owned.append(OwnedPurchase(productID: transaction.productID,
                                       isFamilyShared: transaction.ownershipType == .familyShared,
                                       revokedAt: transaction.revocationDate,
                                       expiresAt: transaction.expirationDate))
            guard transaction.productID == PlanProduct.monthly,
                  transaction.ownershipType == .purchased else { continue }
            groupID = transaction.subscriptionGroupID
            periodEnd = transaction.expirationDate
            if #available(iOS 17.2, *), let offer = transaction.offer {
                freeWeek = offer.type == .introductory && offer.paymentMode == .freeTrial
            }
            monthlyID = freeWeek ? nil : transaction.id
            if let status = await transaction.subscriptionStatus,
               case .verified(let renewal) = status.renewalInfo {
                renews = renewal.willAutoRenew
            }
        }
        access = PlanAccess.resolve(owned, now: .now)
        hasResolved = true
        ownMonthlyRenews = renews
        latestMonthlyTransactionID = monthlyID
        monthlyPeriodEnd = periodEnd
        inFreeWeek = freeWeek
        if let groupID { subscriptionGroupID = groupID }
        await readTrialEligibility()
        if !owned.isEmpty {
            hasBoughtBefore = true
        } else if !access.isOn, !hasBoughtBefore {
            hasBoughtBefore = await Self.anyPastPurchase()
        }
    }

    /// Whether StoreKit's history holds any purchase of the plan, expired or refunded. Only asked
    /// while the plan is off: it decides one headline (D4).
    private static func anyPastPurchase() async -> Bool {
        for await result in Transaction.all {
            if case .verified(let transaction) = result, PlanProduct.all.contains(transaction.productID) {
                return true
            }
        }
        return false
    }

    // MARK: - Products

    var monthlyProduct: Product? { products[PlanProduct.monthly] }
    var payOnceProduct: Product? { products[PlanProduct.payOnce] }

    /// Both prices, as the offer writes them (`Product.planPrice`), and the free week while this
    /// player can still have it.
    struct OfferPrices: Equatable {
        let monthly: String
        let payOnce: String
        var trial: PlanTrial?
    }

    /// What the offer states: both products' prices once they have loaded, a preview's otherwise, and
    /// `nil` while there is nothing honest to show.
    var offerPrices: OfferPrices? {
        if let monthly = monthlyProduct, let payOnce = payOnceProduct {
            return OfferPrices(monthly: monthly.planPrice, payOnce: payOnce.planPrice,
                               trial: trialEligible ? trialOffer : nil)
        }
        return previewPrices
    }

    /// The monthly's free period as App Store Connect sets it (D1), whether or not this player can
    /// still have it. *Your plan* names it during the week.
    var trialOffer: PlanTrial? {
        guard let offer = monthlyProduct?.subscription?.introductoryOffer else { return previewPrices?.trial }
        return offer.paymentMode == .freeTrial ? PlanTrial(offer.period) : nil
    }

    /// Ask StoreKit whether this Apple Account can still have the free week. Needs the subscription
    /// group, so it waits for the monthly product or a monthly transaction.
    private func readTrialEligibility() async {
        guard loadsProducts,
              let groupID = monthlyProduct?.subscription?.subscriptionGroupID ?? subscriptionGroupID else { return }
        trialEligible = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
    }

    /// Load both products once; a retry after a failure loads them again.
    func loadProducts() async {
        guard loadsProducts, products.count < PlanProduct.all.count else { return }
        do {
            let loaded = try await Product.products(for: PlanProduct.all)
            products = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            productsUnavailable = products.count < PlanProduct.all.count
            if subscriptionGroupID == nil {
                subscriptionGroupID = monthlyProduct?.subscription?.subscriptionGroupID
            }
            await readTrialEligibility()
        } catch {
            productsUnavailable = true
        }
    }

    // MARK: - Buying

    /// How a purchase ended, in the terms the wall answers with.
    enum PurchaseOutcome: Equatable {
        case bought
        case cancelled
        /// Ask to Buy, or a payment needing more steps: the plan opens when it is approved.
        case pending
        case failed(String)
    }

    /// Finish a purchase that SwiftUI's `purchase` action returned. The action is read from the view
    /// (it knows which scene to present Apple's sheet in); everything after it happens here.
    func complete(_ result: Product.PurchaseResult) async -> PurchaseOutcome {
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                return .failed("The App Store couldn't confirm that purchase. If you were charged, "
                               + "Restore purchases will find it.")
            }
            await transaction.finish()
            await refresh()
            return .bought
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// *Restore purchases*, which App Review taps. StoreKit 2 already restores on launch, because an
    /// entitlement belongs to the Apple Account and not to the install, so this asks the App Store
    /// to re-sync and reads again. Returns whether the plan is on afterwards.
    func restore() async -> Bool {
        try? await AppStore.sync()
        await refresh()
        return access.isOn
    }
}

extension Product {
    /// The price as Red Moon writes it: whole amounts without pence (`PlanPrice`), anything else as
    /// StoreKit formats it for the storefront.
    var planPrice: String {
        guard PlanPrice.isWhole(price) else { return displayPrice }
        return price.formatted(priceFormatStyle.precision(.fractionLength(0)))
    }
}

extension PlanTrial {
    /// StoreKit's period, mapped at the boundary so `PlanTrial` stays Foundation-only.
    init?(_ period: Product.SubscriptionPeriod) {
        let unit: Unit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: return nil
        }
        self.init(unit: unit, value: period.value)
    }
}

extension Optional where Wrapped == PlanStore {
    /// Whether the plan is on, for a view that may have no store (`accessWithoutStore`).
    @MainActor var planIsOn: Bool { (self?.access ?? PlanStore.accessWithoutStore).isOn }

    /// Whether a gated door draws its lock: StoreKit has answered, and the plan is off.
    @MainActor var showsPlanLocks: Bool { (self?.hasResolved ?? true) && !planIsOn }
}

extension PlanStore {
    /// What a view reads when there is no store in its environment (D9): no plan, so a view outside
    /// the root fails closed. An Xcode preview is the one exception, because the previews are where
    /// screens get checked, and a wall in every preview would hide the screen being checked.
    nonisolated static let accessWithoutStore: PlanAccess =
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ? .payOnce : .none
}
