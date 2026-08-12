import SwiftUI

/// **Settings ▸ Song player** (ADR 0162 D2) — the waveform screen's persistent chrome: which side the
/// Loop button sits on, whether the minimap and marker labels show, and how pinch-zoom behaves.
///
/// **Renamed from "Transport".** That was engineer's jargon that escaped into the UI; the people this
/// ships to call it the song player, or nothing at all.
///
/// ADR 0162 D9 deliberately leaves open the *other* question about these four — ADR 0050's scope
/// discipline would arguably make the minimap, marker labels and zoom behaviour contextual controls
/// on the waveform screen itself rather than global preferences. That is a question about where a
/// setting lives in the app; 0162 was only about where it lives inside Settings.
struct SongPlayerSettingsView: View {
    @AppStorage(AppSettings.Key.transportLoopOnLeft) private var transportLoopOnLeft = false
    @AppStorage(AppSettings.Key.waveformMinimapVisible) private var waveformMinimapVisible = true
    @AppStorage(AppSettings.Key.waveformMarkerLabels) private var waveformMarkerLabels = true
    @AppStorage(AppSettings.Key.zoomFollowsPlayhead) private var zoomFollowsPlayhead = false

    var body: some View {
        Form {
            Section {
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
        }
        .settingsScreen(title: "Song player")
    }
}

#Preview {
    NavigationStack { SongPlayerSettingsView() }
        .preferredColorScheme(.dark)
}
