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

    /// Whether the first `refreshEntitlements()` has completed. `isPro` starts `false` and the scan is
    /// `async`, so **before this flips there is no difference between "not subscribed" and "we haven't
    /// looked yet"** — and ADR 0144's launch wall must not flash at a paying subscriber during that
    /// gap. Gates read plain `isPro` (locked-until-proven is the safe default for a *gate*); only the
    /// unprompted launch cover waits on this. Never returns to `false`.
    private(set) var hasResolvedEntitlements = false

    /// When the current subscription period ends — the trial's conversion instant while a trial is
    /// running (ADR 0144 D6). `nil` when nothing is owned, or when StoreKit can't tell us.
    private(set) var currentExpiration: Date?

    /// Whether the current subscription is still set to renew. `false` once the player cancels, which
    /// is the signal that stops the trial reminder: they've already decided.
    private(set) var willAutoRenew = false

    /// Called after every entitlement refresh with the two facts the trial reminder needs. A closure
    /// rather than a direct dependency, so `StoreManager` stays the app's only StoreKit type and
    /// gains no knowledge of `UserNotifications`; the app root wires the two together.
    var onSubscriptionStateChange: (@MainActor (Date?, Bool) -> Void)?

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
        if UITestRuntime.isActive {
            debugProOverride = true
        }
        #endif
        // TODO(beta): remove with the rest of the closed-beta grant.
        // Resolve the beta grant **synchronously, from the receipt path**, before the first paint —
        // see `resolveSandbox(receiptURL:)`. This is what makes the grant survive a first install:
        // the `AppTransaction` route below cannot answer until a network round trip completes, and on
        // a fresh TestFlight install there is nothing cached for it to read.
        isSandboxBuild = Self.betaGrantIsReadable
            && Self.resolveSandbox(receiptURL: Bundle.main.appStoreReceiptURL)
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
        // TODO(beta): remove with the rest of the closed-beta grant.
        // Its **own** task, deliberately: this read can stall on the network, and awaited from
        // inside `refreshEntitlements()` it delayed `hasResolvedEntitlements` — and so the whole
        // app's entitlement answer — behind a beta convenience. Nothing waits on it now.
        Task { await confirmBetaGrantIfNeeded() }
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
        hasResolvedEntitlements = true
        recomputeIsPro()
        await refreshSubscriptionState()
        onSubscriptionStateChange?(currentExpiration, willAutoRenew)
    }

    /// Read the owned subscription's renewal state. Needs `products`, so it loads them on demand —
    /// this runs at launch, before the paywall has ever been opened.
    private func refreshSubscriptionState() async {
        guard let owned = entitledProductIDs.first else {
            currentExpiration = nil
            willAutoRenew = false
            return
        }
        if products.isEmpty { await loadProducts() }
        guard let subscription = products.first(where: { $0.id == owned })?.subscription,
              let statuses = try? await subscription.status else { return }
        for status in statuses {
            guard case .verified(let renewal) = status.renewalInfo,
                  case .verified(let transaction) = status.transaction,
                  entitledProductIDs.contains(transaction.productID) else { continue }
            currentExpiration = transaction.expirationDate
            willAutoRenew = renewal.willAutoRenew
            return
        }
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
        let wasPro = isPro
        try? await AppStore.sync()
        await refreshEntitlements()
        // Whether the restore actually found anything (ADR 0120) — the difference between "restore
        // works" and "restore keeps being tried and failing", which look identical in ASC.
        Analytics.send(.restoreCompleted(restored: !wasPro && isPro))
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
        isPro = Self.resolveIsPro(entitled: !entitledProductIDs.isEmpty,
                                  debugOverride: override,
                                  betaGrant: isSandboxBuild)
    }

    /// Pure entitlement decision, extracted so it's unit-testable without StoreKit: a debug override
    /// wins when present, otherwise Pro follows whether any Pro product is entitled **or** the
    /// closed-beta grant applies. `nonisolated` — it touches no actor state, so gates/tests can call
    /// it from any context.
    nonisolated static func resolveIsPro(entitled: Bool, debugOverride: Bool?, betaGrant: Bool = false) -> Bool {
        debugOverride ?? (entitled || betaGrant)
    }

    // MARK: - Closed-beta entitlement grant

    /// **TODO(beta): remove before the next App Store submission.** Tracked in
    /// `docs/plans/beta-testing-plan.md`; this comment is the grep target.
    ///
    /// Whether this build runs against the StoreKit **sandbox**, which for a distributed build means
    /// **TestFlight**. Closed-beta testers are granted Pro outright so the round can study the
    /// practice loop rather than a purchase decision: `debugProOverride` is `#if DEBUG` only and
    /// TestFlight ships Release builds, so without this every tester meets the ADR 0144 D4 launch
    /// wall on every cold launch with Practice, the library and the planner all locked.
    ///
    /// **This cannot reach a paying customer.** An App Store download carries a receipt named
    /// `receipt` and reports `AppStore.Environment.production`; only sandbox and TestFlight installs
    /// carry `sandboxReceipt` and report `.sandbox`. The whole exposure is that a TestFlight tester
    /// gets Pro free, which is the intent.
    private var isSandboxBuild = false

    /// Latch, so the async confirmation below runs once per launch rather than on every refresh.
    /// **Set only on a conclusive answer** — see `confirmBetaGrantIfNeeded()`.
    private var hasResolvedEnvironment = false

    /// The sandbox decision, as a pure function of the receipt's filename, so the rule that actually
    /// decides a tester's entitlement is unit-testable. The wiring in `init` supplies
    /// `Bundle.main.appStoreReceiptURL`.
    ///
    /// **Synchronous and offline by design.** The first implementation asked `AppTransaction` and got
    /// three failure modes for its trouble — it is `async`, so gates painted locked until it landed;
    /// it needs the network when nothing is cached, which is exactly the first launch after an
    /// install; and it can stall, which delayed the entitlement answer for the whole app. The receipt
    /// path is present at process start, needs no network, no App Store sign-in and no verification,
    /// and answers the same question.
    nonisolated static func resolveSandbox(receiptURL: URL?) -> Bool {
        receiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// **TODO(beta): remove with the rest of the closed-beta grant.** One line a tester can read out
    /// of Settings ▸ Red Moon Pro, so "the paywall is showing" becomes a fact instead of a guess.
    ///
    /// This exists because the grant is the one rule in the app that **cannot be observed anywhere it
    /// runs**: it is compiled out of Debug, so the simulator, a local device build and every UI test
    /// all skip it, and the only place it takes effect is a build nobody can attach a debugger to.
    /// Two rounds of tester prose were read wrong before this was added.
    var betaDiagnostic: String {
        let receipt = Bundle.main.appStoreReceiptURL?.lastPathComponent ?? "none"
        return "receipt: \(receipt) · grant: \(isSandboxBuild ? "on" : "off") · pro: \(isPro ? "yes" : "no")"
    }

    /// Whether the beta grant may be resolved at all. **Not in a Debug build**, which has
    /// `debugProOverride` and so has nothing to gain from it — and where granting silently would make
    /// the locked states unreachable locally, which is where they are checked (see
    /// `docs/plans/storekit-sandbox-validation.md`).
    ///
    /// Written as a runtime flag over a `#if` rather than fencing the call sites, so the code below
    /// still **type-checks in a Debug build** — the local `xcodebuild build` is Debug, and code that
    /// only compiles in Release is code nothing checks until upload.
    private static var betaGrantIsReadable: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }

    /// Second opinion on the grant, from `AppTransaction`. **Belt-and-braces only** — the receipt
    /// check in `init` is the primary route and has already run by the time this does.
    ///
    /// **Fails closed and never latches on a failure.** Any error, any unverified result, and the
    /// environment is simply left unanswered so the next launch tries again; the previous version
    /// latched *before* the read, so a single failure disabled the grant for the rest of the launch
    /// and no foreground refresh could recover it. Never calls `AppTransaction.refresh()` — a beta
    /// convenience must not put an auth sheet in front of a launching app.
    private func confirmBetaGrantIfNeeded() async {
        guard !hasResolvedEnvironment, Self.betaGrantIsReadable else { return }
        // The receipt already answered it; no need to ask the network.
        if isSandboxBuild {
            hasResolvedEnvironment = true
            return
        }
        guard let result = try? await AppTransaction.shared,
              case .verified(let appTransaction) = result else { return }
        hasResolvedEnvironment = true
        guard appTransaction.environment == .sandbox else { return }
        isSandboxBuild = true
        recomputeIsPro()
    }
}
