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
    @AppStorage(AppSettings.Key.routineAutoStart) private var routineAutoStart = true
    @AppStorage(AppSettings.Key.routineReflection) private var routineReflection = true
    @AppStorage(AppSettings.Key.routineRestSeconds) private var routineRestSeconds = 20
    @AppStorage(AppSettings.Key.routineSongLoop) private var routineSongLoop = true

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

            Section {
                Toggle("Haptics", isOn: $hapticsEnabled)
            } header: {
                Text("Feel")
            } footer: {
                Text("Light taps that confirm gestures like setting a loop or tapping tempo.")
            }

            Section {
                Toggle("Count-in", isOn: $countInEnabled)
                if countInEnabled {
                    Stepper(value: $countInBars, in: AppSettings.countInBarsRange) {
                        LabeledContent("Count-in length", value: barsLabel(countInBars))
                    }
                }
                Toggle("Keep screen awake", isOn: $keepScreenAwake)
            } header: {
                Text("Practice")
            } footer: {
                Text("A count-in before a tempo climb begins, so you can settle in. Keeping the "
                     + "screen awake stops it locking while you play along hands-free.")
            }

            Section {
                Toggle("Auto-start blocks", isOn: $routineAutoStart)
                Toggle("Reflect after each block", isOn: $routineReflection)
                Stepper(value: $routineRestSeconds, in: AppSettings.routineRestSecondsRange, step: 5) {
                    LabeledContent("Rest length", value: "\(routineRestSeconds)s")
                }
                Toggle("Loop song blocks", isOn: $routineSongLoop)
            } header: {
                Text("Routines")
            } footer: {
                Text("In a routine, each block after the first starts on its own (the first always "
                     + "waits for you). When a block finishes, a short reflection prompt lets you jot "
                     + "a note before moving on — skip it any time, or turn it off here. Rest length "
                     + "sets the breather between blocks. A song block loops as an open jam and moves "
                     + "on only when you skip; turn Loop song blocks off to play it through once and "
                     + "auto-advance.")
            }

            Section {
                Toggle("Animate exercises", isOn: $exerciseAnimates)
            } header: {
                Text("Motion")
            } footer: {
                Text("A moving highlight walks the exercise in time — the notes on the fretboard, the "
                     + "strokes on the strum lane. Off by default, and always off when your device has "
                     + "Reduce Motion on — some people find blinking motion uncomfortable. With it off, "
                     + "the exercise is shown statically.")
            }

            Section {
                LabeledContent("Version", value: Self.appVersion)
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
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func barsLabel(_ bars: Int) -> String { bars == 1 ? "1 bar" : "\(bars) bars" }

    /// Marketing version from the bundle (`MARKETING_VERSION`), e.g. "0.0.1".
    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
}
