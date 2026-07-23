import SwiftUI

/// App settings (Settings V1, ADR 0050). A thin `Form`, pushed from the Home toolbar gear.
/// Each row is `@AppStorage` on an `AppSettings.Key`, so the value is read elsewhere without a
/// shared object (the audio engine reads `AppSettings.countInEnabled`, the haptic helper reads
/// `AppSettings.hapticsEnabled`). Deliberately small — feature-specific controls (e.g. the
/// contextual gridlines toggle) live on their own screens, not here.
struct SettingsView: View {
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
    }

    private func barsLabel(_ bars: Int) -> String { bars == 1 ? "1 bar" : "\(bars) bars" }

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
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
}
