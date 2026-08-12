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
    /// Injected so previews drive a `RecordingSupportSender` rather than the live endpoint. The
    /// default is the real one, so `SettingsView` stays a plain `AboutSection()`.
    var sender: SupportSending = FormspreeSender()

    /// The sheet is hosted **here, not in `SettingsView`** — that file sits just under SwiftLint's
    /// 400-line ceiling (the same pressure that split this section out in the first place), and the
    /// row that presents it lives in this file anyway.
    @State private var showingContactSupport = false

    var body: some View {
        Section {
            LabeledContent("Version", value: Self.appVersion)

            NavigationLink { FAQView() } label: {
                Text("Help & FAQs")
            }

            // Was a `mailto:`, which **silently does nothing** on a device with no Mail account
            // configured — no error, no sheet, nothing. ADR 0161 replaced it with an in-app form that
            // posts over HTTPS and works whether or not Mail is set up. The plain-text address stays
            // in the "How do I get help?" answer (ADR 0145) and matters more now, not less: the form
            // can fail *out loud*, and when it does it needs somewhere to send the player.
            Button {
                showingContactSupport = true
            } label: {
                LabeledContent("Contact Support") {
                    Image(systemName: "envelope")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)

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
        .sheet(isPresented: $showingContactSupport) {
            ContactSupportSheet(sender: sender)
        }
    }

    /// Marketing version from the bundle (`MARKETING_VERSION`), e.g. "0.0.1".
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
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
