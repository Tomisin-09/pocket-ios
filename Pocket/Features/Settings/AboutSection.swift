import SwiftUI

/// The **About** section of Settings — version, help, the support address, and the two legal links,
/// under the Red Moon wordmark.
///
/// Its own file (like `PrivacySection` and `NoteSpellingSection`) because `SettingsView` sits right on
/// SwiftLint's 400-line ceiling and ADR 0145 adds two rows here. Lifting the section out is what buys
/// the room; nothing about its behaviour changed in the move.
///
/// **Help & FAQs is a `NavigationLink`, not a sheet.** Settings is *pushed* onto the Home stack, so the
/// same `FAQView` the Toolkit shows pushes on top of it and backs out to Settings — one help screen,
/// two doors (ADR 0145 D1).
struct AboutSection: View {
    var body: some View {
        Section {
            LabeledContent("Version", value: Self.appVersion)

            NavigationLink { FAQView() } label: {
                Text("Help & FAQs")
            }

            // ⚠ A `mailto:` **silently does nothing** on a device with no Mail account configured —
            // no error, no sheet, nothing. That is exactly why ADR 0145 requires the address to
            // *also* sit as plain selectable text inside the "How do I get help?" answer. This row is
            // the convenience; that answer is the guarantee.
            if let supportURL = Self.supportURL {
                Link(destination: supportURL) {
                    LabeledContent("Contact Support") {
                        Image(systemName: "envelope")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Apple's standard EULA (the licence that governs use of the app on the
            // App Store) applies by default when we ship no custom terms — see
            // docs/app-store-license-obligations.md. Surfacing the link here satisfies
            // the "Terms of Use (EULA)" disclosure Apple requires once auto-renewable
            // subscriptions ship, and is honest for v1. Swap for a hosted custom-ToS URL
            // if/when the Oracle AI tier introduces its own terms (ADR 0092).
            Link(destination: Self.privacyPolicy) {
                LabeledContent("Privacy Policy") {
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Link(destination: Self.appleStandardEULA) {
                LabeledContent("Terms of Use") {
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("About")
        } footer: {
            // Brand mark. `RedMoonLogo` is a **vector** (SVG) asset carrying a light and a
            // dark appearance (ADR 0061) — the two-tone crescent means it can't be a single
            // template image tinted in code, so the pair stays. Genuinely transparent, so it
            // sits directly on `PocketColor.background` with no seam in either appearance.
            // The app follows the system appearance (ADR 0062), so no colour-scheme pin
            // is needed here.
            Image("RedMoonLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 160)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)
                .accessibilityLabel("Red Moon")
        }
    }

    /// Marketing version from the bundle (`MARKETING_VERSION`), e.g. "0.0.1".
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    /// A `mailto:` to support with the version already in the subject — free triage signal for one
    /// `URLComponents`, and it saves the player looking the number up after we ask for it.
    ///
    /// Optional rather than force-unwrapped: this is composed from a percent-encoding API, and a row
    /// that quietly doesn't render is a far smaller failure than a crash. The FAQ answer carries the
    /// address in plain text regardless.
    private static var supportURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = FAQEntry.supportAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Red Moon Practice \(appVersion) — support")
        ]
        return components.url
    }

    /// Apple's standard Licensed Application End User License Agreement — the licence that
    /// governs use of the app when we ship no custom terms. A valid compile-time literal.
    private static let appleStandardEULA =
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Red Moon Practice's privacy policy. Points at the live section on the Deco Operations
    /// site. When the standalone page ships (docs/site/redmoon-privacy.html), repoint this at
    /// its dedicated URL. A valid compile-time literal.
    private static let privacyPolicy =
        URL(string: "https://decooperations.co.uk/privacy#red-moon-practice")!
}

#Preview {
    NavigationStack {
        Form { AboutSection() }
    }
}
