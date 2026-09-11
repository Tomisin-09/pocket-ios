import SwiftUI

/// The **About** section of Settings — version, help, the support address, and the two legal links,
/// under the Red Moon wordmark.
///
/// Its own file since ADR 0145, when `SettingsView` sat right on SwiftLint's 400-line ceiling and this
/// section needed two more rows. That pressure is gone — ADR 0162 split Settings into a hub, and this
/// section is now hosted by `AboutSettingsView` — but the file stays, because a section this size
/// earns one on its own merits.
///
/// **Help & FAQs is a `NavigationLink`, not a sheet.** Settings is *pushed* onto the Home stack, so the
/// same `FAQView` the Toolkit shows pushes on top of it and backs out to Settings — one help screen,
/// two doors (ADR 0145 D1). Still true one level deeper.
struct AboutSection: View {
    /// Injected so previews drive a `RecordingSupportSender` rather than the live endpoint. The
    /// default is the real one, so `SettingsView` stays a plain `AboutSection()`.
    var sender: SupportSending = FormspreeSender()

    /// The sheet is hosted **here** because the row that presents it lives in this file. It was
    /// originally here to keep `SettingsView` under SwiftLint's 400-line ceiling; that reason expired
    /// with ADR 0162's hub split, and the better one it always also had is the one that remains.
    @State private var showingContactSupport = false

    /// Optional on purpose. The recorder is a `@State` at the `PocketApp` root and reaches here
    /// through the environment; the non-optional form **traps** in every preview and in the settings
    /// UI tests, which build this section without an app root above it (ADR 0183).
    @Environment(DiagnosticsRecorder.self) private var recorder: DiagnosticsRecorder?

    /// The literal is `AppSettings.attachDiagnosticsDefault`, not `false`, because a `@AppStorage`
    /// uses the value it declares for an unset key and does not consult the accessor beside it.
    @AppStorage(AppSettings.Key.attachDiagnostics)
    private var attachDiagnostics = AppSettings.attachDiagnosticsDefault

    /// What travels with a support message, and the **only** route a diagnostic ever takes off the
    /// device: the setting is on, and there is something to report. Read here rather than inside the
    /// sheet so the sheet stays presentable with neither the recorder nor the preference present.
    private var diagnosticLine: String? {
        guard attachDiagnostics else { return nil }
        return recorder?.supportLine
    }

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

            // Beside Contact Support because feeding a support message is its only purpose
            // (ADR 0183). Not a Settings hub destination of its own: a screen a player visits when
            // something has already gone wrong does not earn a permanent row on the top level.
            NavigationLink { DiagnosticsSettingsView() } label: {
                LabeledContent("Diagnostics") {
                    if let count = recorder?.events.count, count > 0 {
                        Text("\(count)")
                    }
                }
            }

            // The permanent door for rating (ADR 0214), and deliberately **not** a second
            // `requestReview()`. App Store Review Guideline 1.1.7 forbids wiring that API to a
            // control the player taps to rate, and it would be the wrong thing here anyway: it shows
            // nothing once its budget is spent, so a tapped row would silently do nothing. The
            // write-review URL always opens. Above the two legal links because those are
            // conventionally last and this is not one of them.
            Link(destination: Self.writeReview) {
                LabeledContent("Rate Red Moon") {
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Apple's standard EULA (the licence that governs use of the app on the
            // App Store) applies by default when we ship no custom terms — see
            // docs/app-store-license-obligations.md. Red Moon sells nothing (ADR 0237), so no
            // store rule requires the link; it stays because the licence does apply and a
            // player should be able to read it. Swap for a hosted custom-ToS URL if/when the
            // Oracle introduces its own terms (ADR 0092).
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
            ContactSupportSheet(sender: sender, diagnosticLine: diagnosticLine)
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

    /// The App Store's **write a review** sheet for Red Moon (ADR 0214).
    ///
    /// `6789618726` is Red Moon's numeric Apple ID from App Store Connect ▸ App Information (given by
    /// the owner, 2026-10-01). It is not derivable from the bundle id and `fastlane/Appfile` carries
    /// only `app_identifier`, so this literal is the one place it lives. Unconfirmable before the app
    /// is live: Apple's public lookup returns nothing for an unreleased app, so the first check that
    /// this row lands on a real page is tapping it on a store build.
    ///
    /// The id stays inside the one literal rather than being interpolated from a separate constant,
    /// so the "a valid compile-time literal" justification the other two URLs here rest on still
    /// holds. If a second door ever wants it, hoist both into a shared type then — not before.
    private static let writeReview =
        URL(string: "https://apps.apple.com/app/id6789618726?action=write-review")!
}

#Preview {
    NavigationStack {
        Form { AboutSection() }
    }
}
