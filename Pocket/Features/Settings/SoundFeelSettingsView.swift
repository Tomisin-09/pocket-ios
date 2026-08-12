import SwiftUI

/// **Settings ▸ Sound & feel** (ADR 0162 D2) — what the app does to your ears and your hands: the
/// metronome's timbre (ADR 0114) and gesture haptics.
///
/// Haptics was a one-row "Feel" section stranded four places above the timbre picker on the flat
/// screen. They are the same idea — the app's non-visual feedback — so they share a destination, and
/// the hub row reports the chosen timbre so the common visit ends without opening this at all.
struct SoundFeelSettingsView: View {
    @AppStorage(AppSettings.Key.hapticsEnabled) private var hapticsEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $hapticsEnabled) {
                    FieldInfoLabel(title: "Haptics", info: SettingsInfo.haptics)
                }
            }

            // Timbre picker with tap-to-hear (ADR 0114, restyled by ADR 0162 D5/D6).
            MetronomeSoundSection()
        }
        .settingsScreen(title: "Sound & feel")
    }
}

#Preview {
    NavigationStack { SoundFeelSettingsView() }
        .preferredColorScheme(.dark)
}
