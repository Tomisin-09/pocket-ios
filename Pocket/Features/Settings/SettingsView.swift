import SwiftData
import SwiftUI

/// App settings (Settings V1, ADR 0050). A thin `Form`, pushed from the Home toolbar gear.
/// Each row is `@AppStorage` on an `AppSettings.Key`, so the value is read elsewhere without a
/// shared object (the audio engine reads `AppSettings.countInEnabled`, the haptic helper reads
/// `AppSettings.hapticsEnabled`). Deliberately small — feature-specific controls (e.g. the
/// contextual gridlines toggle) live on their own screens, not here.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    /// The local artist profile (ADR 0113). At most one row; `.first` is the singleton (or `nil`
    /// on an untouched install, before a name has ever been set).
    @Query private var profiles: [Profile]
    /// Draft of the artist name being edited. Seeded from the profile on appear and committed on
    /// submit / when the screen leaves, so we write the store once per edit rather than per
    /// keystroke (and never insert a row mid-typing).
    @State private var artistNameDraft = ""
    /// Red Moon Pro entitlement (ADR 0112) — drives the real "Red Moon Pro" section (Manage /
    /// Upgrade / Restore). `store` is the entitlement source; `isPro` + the shared paywall carry
    /// preview-safe defaults.
    @Environment(StoreManager.self) private var store
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    /// Presents Apple's native Manage-Subscriptions sheet (subscribers only — no in-app billing UI).
    @State private var showingManageSubscriptions = false

    #if DEBUG
    /// DEBUG-only: lets the developer re-arm the one-time "you've earned a name" prompt without a
    /// data-wiping reinstall (see the Developer section below).
    @AppStorage(AppSettings.Key.artistNamePromptSeen) private var artistNamePromptSeen = false
    /// DEBUG-only: lets the developer re-arm the first-launch curation intake (ADR 0113 S2).
    @AppStorage(AppSettings.Key.artistIntakeSeen) private var artistIntakeSeen = false
    /// DEBUG-only: force the Red Moon Pro entitlement on/off and preview the paywall (ADR 0112).
    @State private var showingDebugPaywall = false

    /// The three debug entitlement choices, bridging `StoreManager.debugProOverride` (a `Bool?`).
    private enum ProOverrideChoice: Hashable { case defaultReal, free, pro }
    private var proOverride: Binding<ProOverrideChoice> {
        Binding(
            get: {
                switch store.debugProOverride {
                case .none: return .defaultReal
                case .some(true): return .pro
                case .some(false): return .free
                }
            },
            set: { choice in
                switch choice {
                case .defaultReal: store.debugProOverride = nil
                case .free: store.debugProOverride = false
                case .pro: store.debugProOverride = true
                }
            }
        )
    }
    #endif

    @AppStorage(AppSettings.Key.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppSettings.Key.countInEnabled) private var countInEnabled = true
    @AppStorage(AppSettings.Key.countInBars) private var countInBars = AppSettings.countInBarsRange.lowerBound
    @AppStorage(AppSettings.Key.keepScreenAwake) private var keepScreenAwake = true
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppearancePreference.system
    @AppStorage(AppSettings.Key.exerciseAnimates) private var exerciseAnimates = false
    @AppStorage(AppSettings.Key.strumClickFollowsPattern) private var strumClickFollowsPattern = true
    @AppStorage(AppSettings.Key.routineAutoStart) private var routineAutoStart = true
    @AppStorage(AppSettings.Key.routineAutoAdvance) private var routineAutoAdvance = false
    @AppStorage(AppSettings.Key.routineRestSeconds) private var routineRestSeconds = 20
    @AppStorage(AppSettings.Key.routineSongLoop) private var routineSongLoop = true
    @AppStorage(AppSettings.Key.transportLoopOnLeft) private var transportLoopOnLeft = false
    @AppStorage(AppSettings.Key.waveformMinimapVisible) private var waveformMinimapVisible = true
    @AppStorage(AppSettings.Key.waveformMarkerLabels) private var waveformMarkerLabels = true
    @AppStorage(AppSettings.Key.zoomFollowsPlayhead) private var zoomFollowsPlayhead = false

    var body: some View {
        Form {
            Section {
                TextField("Artist name", text: $artistNameDraft)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(commitArtistName)
            } header: {
                Text("You")
            } footer: {
                Text("Your artist name greets you on the home screen. Optional, and it stays on this device.")
            }

            // The curation fields (ADR 0113 S2) — the intake's four questions, editable any time.
            ProfileCurationSection(profile: profiles.first)

            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            } footer: {
                Text("System follows your device's Light/Dark setting.")
            }

            Section("Feel") {
                Toggle(isOn: $hapticsEnabled) {
                    FieldInfoLabel(title: "Haptics", info: SettingsInfo.haptics)
                }
            }

            Section("Practice") {
                Toggle(isOn: $countInEnabled) {
                    FieldInfoLabel(title: "Count-in", info: SettingsInfo.countIn)
                }
                if countInEnabled {
                    Stepper(value: $countInBars, in: AppSettings.countInBarsRange) {
                        LabeledContent("Count-in length", value: barsLabel(countInBars))
                    }
                }
                Toggle(isOn: $keepScreenAwake) {
                    FieldInfoLabel(title: "Keep screen awake", info: SettingsInfo.keepScreenAwake)
                }
                Toggle(isOn: $strumClickFollowsPattern) {
                    FieldInfoLabel(title: "Strumming click follows the pattern",
                                   info: SettingsInfo.strumClick)
                }
            }

            // Metronome timbre picker with inline audition (ADR 0114). Its own section so each preset
            // reads as a row with a play button, rather than crowding the Practice toggles.
            MetronomeSoundSection()

            Section("Routines") {
                Toggle(isOn: $routineAutoStart) {
                    FieldInfoLabel(title: "Auto-start blocks", info: SettingsInfo.routineAutoStart)
                }
                Toggle(isOn: $routineAutoAdvance) {
                    FieldInfoLabel(title: "Advance automatically", info: SettingsInfo.routineAutoAdvance)
                }
                Stepper(value: $routineRestSeconds, in: AppSettings.routineRestSecondsRange, step: 5) {
                    LabeledContent {
                        Text("\(routineRestSeconds)s")
                    } label: {
                        FieldInfoLabel(title: "Rest length", info: SettingsInfo.routineRest)
                    }
                }
                Toggle(isOn: $routineSongLoop) {
                    FieldInfoLabel(title: "Loop song blocks", info: SettingsInfo.routineSongLoop)
                }
            }

            Section("Transport") {
                Toggle(isOn: $transportLoopOnLeft) {
                    FieldInfoLabel(title: "Loop control on left", info: SettingsInfo.transportLoopOnLeft)
                }
                Toggle(isOn: $waveformMinimapVisible) {
                    FieldInfoLabel(title: "Show minimap", info: SettingsInfo.minimap)
                }
                Toggle(isOn: $waveformMarkerLabels) {
                    FieldInfoLabel(title: "Show marker labels", info: SettingsInfo.markerLabels)
                }
                Toggle(isOn: $zoomFollowsPlayhead) {
                    FieldInfoLabel(title: "Zoom follows playhead", info: SettingsInfo.zoomFollowsPlayhead)
                }
            }

            Section("Motion") {
                Toggle(isOn: $exerciseAnimates) {
                    FieldInfoLabel(title: "Animate exercises", info: SettingsInfo.animateExercises)
                }
            }

            // Red Moon Pro (ADR 0112): a subscriber manages/cancels via Apple's native sheet; a free
            // player gets a way into the paywall. Restore is always available (App Review requires it).
            Section {
                if isPro {
                    Button("Manage Subscription") { showingManageSubscriptions = true }
                } else {
                    Button("Upgrade to Red Moon Pro") { presentPaywall(.general) }
                }
                Button("Restore Purchases") { Task { await store.restore() } }
            } header: {
                Text("Red Moon Pro")
            } footer: {
                Text(isPro
                     ? "You have Red Moon Pro. Manage or cancel anytime in Manage Subscription."
                     : "Unlock the full exercise catalog, “draw your own”, and Today's session.")
            }

            #if DEBUG
            // DEBUG-only scaffold (never ships): flip the Red Moon Pro entitlement to watch the
            // paywall gates lock/unlock live, and open the paywall directly (ADR 0112).
            Section {
                Picker("Entitlement", selection: proOverride) {
                    Text("Default").tag(ProOverrideChoice.defaultReal)
                    Text("Free").tag(ProOverrideChoice.free)
                    Text("Pro").tag(ProOverrideChoice.pro)
                }
                .pickerStyle(.segmented)
                LabeledContent("Currently", value: store.isPro ? "Pro" : "Free")
                Button("Show paywall") { showingDebugPaywall = true }
            } header: {
                Text("Red Moon Pro (Debug)")
            } footer: {
                Text("DEBUG only. Force the Pro entitlement on or off to exercise the paywall gates "
                     + "before StoreKit sandbox exists. “Default” uses the real StoreKit entitlement.")
            }

            // DEBUG-only scaffold (never ships): re-arm the one-time artist-name prompt so the
            // ceremony can be re-tested on a real install without a data-wiping reinstall.
            Section {
                Button("Reset naming prompt", role: .destructive, action: resetNamingPrompt)
                Button("Reset first-launch intake", role: .destructive, action: resetIntake)
            } header: {
                Text("Developer")
            } footer: {
                Text("DEBUG only. Clears your artist name and re-arms the “you've earned a name” "
                     + "prompt; the second row re-arms the first-launch curation intake.")
            }
            #endif

            Section {
                LabeledContent("Version", value: Self.appVersion)
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
                // Brand mark. The RedMoonLogo asset carries both light (cream-outlined) and
                // dark (near-black-outlined) artwork (ADR 0061) with the surrounding card
                // background keyed out to transparent (ADR 0062 follow-up) — it sits
                // directly on `PocketColor.background` with no seam, in either appearance,
                // rather than floating a slightly-mismatched solid-colour rectangle on top.
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
        .scrollContentBackground(.hidden)
        // Cap the form to a readable column at regular width (iPad / landscape); no-op at
        // compact width, dormant on the iPhone-only v1 build (ADR 0105).
        .readableWidth()
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { artistNameDraft = profiles.first?.artistName ?? "" }
        // Commit when the screen leaves too, so an edit the user typed without pressing Done
        // still saves.
        .onDisappear(perform: commitArtistName)
        // Apple's native Manage-Subscriptions screen — the ADR 0112 "no in-app billing UI" contract.
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        #if DEBUG
        .sheet(isPresented: $showingDebugPaywall) {
            PaywallView(trigger: .general).environment(store)
        }
        #endif
    }

    private func barsLabel(_ bars: Int) -> String { bars == 1 ? "1 bar" : "\(bars) bars" }

    /// Persist the drafted artist name to the local profile (creating the singleton row on first
    /// non-empty name, clearing it back to name-free when blank).
    private func commitArtistName() {
        Profile.setArtistName(artistNameDraft, in: context)
    }

    #if DEBUG
    /// DEBUG-only: clear the artist name and re-arm the one-time naming prompt, so the "you've
    /// earned a name" ceremony can be exercised again on a real install (no reinstall / data loss).
    private func resetNamingPrompt() {
        Profile.setArtistName(nil, in: context)
        artistNamePromptSeen = false
        artistNameDraft = ""
    }

    /// DEBUG-only: re-arm the one-time first-launch curation intake so it can be re-tested on a real
    /// install. Leaves the stored curation in place (it stays visible/editable in "Your sound"); this
    /// only flips the "seen" gate so Home offers the flow again on next appearance.
    private func resetIntake() {
        artistIntakeSeen = false
    }
    #endif

    /// Marketing version from the bundle (`MARKETING_VERSION`), e.g. "0.0.1".
    private static var appVersion: String {
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

/// The per-row ⓘ copy, centralised the way `PracticeFieldInfo` is for the loop sheet. Moving the
/// explanations off the section footers and onto each row's `FieldInfoLabel` keeps the list scannable
/// while the nuance stays a tap away. The Appearance picker has no label slot for an ⓘ, so it keeps its
/// short footer instead.
enum SettingsInfo {
    static let haptics =
        "Light taps that confirm gestures like setting a loop or tapping tempo."
    static let countIn =
        "A count-in before a tempo climb begins, so you can settle in before playing."
    static let keepScreenAwake =
        "Stops the screen locking while you play along hands-free."
    static let strumClick =
        "For a strumming drill, the metronome plays the pattern's rhythm (down/up/accent). Turned "
        + "off, it's a plain click you strum the rhythm against."
    static let routineAutoStart =
        "In a routine, each block after the first starts on its own — the first always waits for you."
    static let routineAutoAdvance =
        "When a block finishes, a Done screen lets you rate how it felt and jot a note. Turn this on "
        + "to skip it and go straight to the next block."
    static let routineRest =
        "The breather between blocks."
    static let routineSongLoop =
        "A song block loops as an open jam and moves on only when you skip. Off plays it through once, "
        + "then auto-advances."
    static let transportLoopOnLeft =
        "Big Loop and Marker buttons flank the transport bar while idle. Marker sits on the left and "
        + "Loop on the right by default — turn this on to swap them."
    static let minimap =
        "The full-song overview strip under the waveform. Off gives the waveform and loops a little "
        + "more room."
    static let markerLabels =
        "Floats a marker's name over the timeline as you play up to it. Off keeps labels in the "
        + "Markers panel only."
    static let zoomFollowsPlayhead =
        "Pinch-zoom normally keeps the spot under your fingers still. Turn this on to have the "
        + "window re-center on the playhead as you zoom instead."
    static let animateExercises =
        "A moving highlight walks the exercise in time — the notes on the fretboard, the strokes on "
        + "the strum lane. Always off when your device has Reduce Motion on."
}

// Regular-width variant (ADR 0105): caps to a centred column at iPad / landscape width.
#Preview("Settings — regular width (iPad groundwork)") {
    NavigationStack { SettingsView() }
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 900)
        .modelContainer(for: Profile.self, inMemory: true)
        .environment(StoreManager())
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
        .modelContainer(for: Profile.self, inMemory: true)
        .environment(StoreManager())
}
