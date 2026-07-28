import Foundation
import Observation
import StoreKit

/// The **one** source of truth for the player's Red Moon Pro entitlement (ADR 0112). Wraps StoreKit 2:
/// it resolves `Transaction.currentEntitlements` at launch, listens to `Transaction.updates` for
/// renewals/revocations/refunds, and publishes `isPro`. Injected into the SwiftUI environment as the
/// only type in the app that talks to StoreKit — every paywall gate reads `isPro` **through**
/// `AccessPolicy`, never StoreKit directly.
///
/// StoreKit serves the cached entitlement **offline**, so `isPro` resolves with no spinner and no
/// network dependency to use the app. Access is computed live (ADR 0112 "gate at read time"): when an
/// entitlement lapses, `isPro` flips to `false` and every Pro surface re-locks with no migration.
@MainActor
@Observable
final class StoreManager {

    /// The Red Moon Pro product identifiers (ADR 0112) — must match the bundled `.storekit` config
    /// and, later, the App Store Connect products.
    enum ProductID {
        static let monthly = "click.decooperations.pocket.pro.monthly"
        static let annual  = "click.decooperations.pocket.pro.annual"
        /// **Annual first** — the paywall leads with the annual upgrade (ADR 0112).
        static let all: [String] = [annual, monthly]
    }

    /// Whether the player currently holds an active Pro entitlement. The value every gate reads.
    private(set) var isPro: Bool = false

    /// The loaded subscription products, annual-first, for the paywall. Empty until `loadProducts()`.
    private(set) var products: [Product] = []

    /// Verified, non-revoked Pro product IDs the player currently owns.
    private var entitledProductIDs: Set<String> = []

    #if DEBUG
    /// Debug-only entitlement override, so gates can be exercised before ASC/sandbox exists. `nil` =
    /// use the real StoreKit entitlement; `true`/`false` force it. Persisted so a relaunch remembers.
    var debugProOverride: Bool? {
        didSet {
            let encoded = debugProOverride.map { $0 ? 1 : 0 } ?? -1
            UserDefaults.standard.set(encoded, forKey: Self.debugOverrideKey)
            recomputeIsPro()
        }
    }
    static let debugOverrideKey = "debugProOverride"
    #endif

    init() {
        #if DEBUG
        // -1 (or absent) = no override; 0/1 = forced off/on.
        if let stored = UserDefaults.standard.object(forKey: Self.debugOverrideKey) as? Int {
            debugProOverride = stored < 0 ? nil : (stored == 1)
        }
        // UI tests run **fully unlocked** so entitlement gating never blocks a feature flow under
        // test (the gating itself is unit-tested — `AccessPolicyTests`). Setting the override in
        // `init` deliberately skips its `didSet`, so this is **not** persisted and can't leak into a
        // later launch; and it's DEBUG-only + launch-args can't be set by an App Store user, so it is
        // never a Release entitlement bypass.
        if CommandLine.arguments.contains("-uiTesting") {
            debugProOverride = true
        }
        #endif
        // Apply any override synchronously so the first paint already reflects it (no flash of locked
        // content, and no race for a UI test that taps before the async entitlement refresh lands).
        recomputeIsPro()
        // Listen for renewals / revocations / refunds for the life of the app (weak self; the
        // manager is an app-lifetime singleton, so the stream is never orphaned in practice).
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refreshEntitlements() }
    }

    /// Re-scan current entitlements and recompute `isPro`. Safe to call any time (launch, post-purchase,
    /// restore).
    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            owned.insert(transaction.productID)
        }
        entitledProductIDs = owned
        recomputeIsPro()
    }

    /// Load the subscription products for the paywall, preserving the annual-first order regardless of
    /// StoreKit's return order. No-op-safe: on failure `products` is left empty and the paywall can retry.
    func loadProducts() async {
        guard let loaded = try? await Product.products(for: ProductID.all) else {
            products = []
            return
        }
        products = ProductID.all.compactMap { id in loaded.first { $0.id == id } }
    }

    /// Buy `product`. Returns `true` iff the purchase completed and Pro is now active; `false` for
    /// user-cancel / pending / unverified. Throws only on StoreKit's own purchase errors.
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            await transaction.finish()
            await refreshEntitlements()
            return isPro
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Restore purchases — re-sync with the App Store, then re-scan entitlements. Backs the paywall's
    /// **Restore Purchases** control (required by App Review).
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    /// The single place `isPro` is set — routed through the pure resolver so the rule is testable.
    private func recomputeIsPro() {
        var override: Bool?
        #if DEBUG
        override = debugProOverride
        #endif
        isPro = Self.resolveIsPro(entitled: !entitledProductIDs.isEmpty, debugOverride: override)
    }

    /// Pure entitlement decision, extracted so it's unit-testable without StoreKit: a debug override
    /// wins when present, otherwise Pro follows whether any Pro product is entitled. `nonisolated` —
    /// it touches no actor state, so gates/tests can call it from any context.
    nonisolated static func resolveIsPro(entitled: Bool, debugOverride: Bool?) -> Bool {
        debugOverride ?? entitled
    }
}
