import StoreKit
import SwiftUI

/// The Red Moon Pro paywall (ADR 0112). One screen, presented by the shared `.presentPaywall` action.
/// On-brand (crescent seal · Futura · design tokens, theme-aware) but a **conversion** surface first:
/// a contextual headline, three value lines, **Annual pre-selected** over Monthly, one primary CTA,
/// Restore, and the App-Review-required disclosure block (auto-renew · price · cancel anytime) with
/// Terms + Privacy links. Prices and trial-eligibility come live from StoreKit via `StoreManager`.
struct PaywallView: View {
    let trigger: PaywallTrigger

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Plan { case annual, monthly }
    @State private var plan: Plan = .annual
    @State private var eligibleForTrial = true
    @State private var purchasing = false
    @State private var purchaseError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                valueProps
                plans
                cta
                disclosure
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .task { await load() }
        .alert("Purchase failed", isPresented: showingError) {
            Button("OK", role: .cancel) { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            Image("RedMoonMark")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text("Red Moon Pro")
                .font(.futura(.largeTitle, weight: .bold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(trigger.headline)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    // MARK: - Value props

    private var valueProps: some View {
        VStack(alignment: .leading, spacing: 16) {
            valueRow("square.grid.3x3.fill", "The full exercise catalog",
                     "Every scale, chord, arpeggio and technique drill — no limits.")
            valueRow("hand.draw.fill", "Draw your own",
                     "Hand-shape any exercise on the fretboard canvas.")
            valueRow("sparkles", "Today's session",
                     "A fresh, self-guided practice plan built from your goals.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.practice)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.futura(.body, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(subtitle)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    // MARK: - Plans

    private var plans: some View {
        VStack(spacing: 12) {
            planCard(.annual, title: "Annual", price: annualPriceText,
                     caption: annualCaption, badge: "Best value")
            planCard(.monthly, title: "Monthly", price: monthlyPriceText,
                     caption: "Billed monthly", badge: nil)
        }
    }

    private func planCard(_ candidate: Plan, title: String, price: String,
                          caption: String, badge: String?) -> some View {
        let selected = plan == candidate
        return Button {
            plan = candidate
            haptic(.light)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.futura(.title3))
                    .foregroundStyle(selected ? PocketColor.practice : PocketColor.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.futura(.body, weight: .semibold))
                            .foregroundStyle(PocketColor.textPrimary)
                        if let badge { bestValueBadge(badge) }
                    }
                    Text(caption)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Text(price)
                    .font(.futura(.body, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? PocketColor.practice.opacity(0.12) : PocketColor.surfaceStandard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? PocketColor.practice : PocketColor.surfaceBorder,
                            lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func bestValueBadge(_ text: String) -> some View {
        Text(text)
            .font(.futura(.caption2, weight: .bold))
            .foregroundStyle(PocketColor.background)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(PocketColor.practice))
    }

    // MARK: - CTA

    private var cta: some View {
        VStack(spacing: 12) {
            Button { Task { await buy() } } label: {
                Group {
                    if purchasing {
                        ProgressView().tint(PocketColor.background)
                    } else {
                        Text(ctaTitle)
                            .font(.futura(.headline))
                            .foregroundStyle(PocketColor.background)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCTA))
            }
            .buttonStyle(.plain)
            .disabled(purchasing || selectedProduct == nil)

            Button("Restore Purchases") { Task { await restore() } }
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.practice)
                .disabled(purchasing)
        }
    }

    private var ctaTitle: String {
        eligibleForTrial ? "Start 14-day free trial" : "Subscribe"
    }

    // MARK: - Disclosure (App Review requires this block)

    private var disclosure: some View {
        VStack(spacing: 10) {
            Text(disclosureText)
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Terms of Use", destination: Self.termsURL)
                Text("·").foregroundStyle(PocketColor.textSecondary)
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.futura(.caption2, weight: .semibold))
            .tint(PocketColor.practice)
        }
        .padding(.top, 4)
    }

    private var disclosureText: String {
        "Red Moon Pro is an auto-renewing subscription. "
        + (eligibleForTrial
           ? "Your 14-day free trial converts to the selected plan unless cancelled at least 24 hours "
             + "before it ends. "
           : "")
        + "Payment is charged to your Apple Account at confirmation. It renews automatically unless "
        + "turned off at least 24 hours before the period ends. Manage or cancel anytime in Settings."
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.futura(.title2))
                .foregroundStyle(PocketColor.textSecondary)
                .padding(16)
        }
        .accessibilityLabel("Close")
    }

    // MARK: - Pricing text (live, with a safe fallback before products load)

    private var annualProduct: Product? {
        store.products.first { $0.id == StoreManager.ProductID.annual }
    }
    private var monthlyProduct: Product? {
        store.products.first { $0.id == StoreManager.ProductID.monthly }
    }
    private var selectedProduct: Product? {
        plan == .annual ? annualProduct : monthlyProduct
    }

    private var annualPriceText: String {
        annualProduct.map { "\($0.displayPrice)/yr" } ?? "£49.99/yr"
    }
    private var monthlyPriceText: String {
        monthlyProduct.map { "\($0.displayPrice)/mo" } ?? "£5.99/mo"
    }

    /// The per-month equivalent of the annual plan — the retention lever this category lives on.
    private var annualCaption: String {
        guard let annual = annualProduct else { return "≈ £4.17/mo · best value" }
        let perMonth = annual.price / 12
        let formatted = perMonth.formatted(annual.priceFormatStyle)
        return "≈ \(formatted)/mo · best value"
    }

    // MARK: - Actions

    private func load() async {
        await store.loadProducts()
        if let sub = annualProduct?.subscription {
            eligibleForTrial = await sub.isEligibleForIntroOffer
        }
    }

    private func buy() async {
        guard let product = selectedProduct else { return }
        purchasing = true
        defer { purchasing = false }
        do {
            if try await store.purchase(product) {
                // Reported here rather than in `StoreManager` because trial eligibility is only
                // known on this screen (ADR 0120) — and trial-vs-outright is the interesting half.
                Analytics.send(.purchaseCompleted(product: plan == .annual ? .annual : .monthly,
                                                  trial: eligibleForTrial))
                dismiss()
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func restore() async {
        purchasing = true
        defer { purchasing = false }
        await store.restore()
        if store.isPro { dismiss() }
    }

    private var showingError: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    /// Apple's standard EULA — the licence that governs the app when we ship no custom terms; the
    /// "Terms of Use (EULA)" disclosure Apple requires once auto-renewable subscriptions ship. Mirrors
    /// the link in Settings.
    private static let termsURL =
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL =
        URL(string: "https://decooperations.co.uk/privacy#red-moon-practice")!
}

#Preview("Paywall — draw your own") {
    PaywallView(trigger: .drawYourOwn)
        .environment(StoreManager())
}
