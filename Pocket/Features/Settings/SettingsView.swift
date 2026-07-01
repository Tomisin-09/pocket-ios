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

    var body: some View {
        Form {
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
                LabeledContent("Version", value: Self.appVersion)
            } header: {
                Text("About")
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
