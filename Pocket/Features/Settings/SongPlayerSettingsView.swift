import SwiftUI

/// **Settings ▸ Song player** (ADR 0162 D2) — the waveform screen's persistent chrome: which side the
/// Loop button sits on, whether the minimap and marker labels show, how pinch-zoom behaves, and —
/// since ADR 0194 — how much a seek release snaps to what is drawn.
///
/// **Renamed from "Transport".** That was engineer's jargon that escaped into the UI; the people this
/// ships to call it the song player, or nothing at all.
///
/// **Two doors, one screen (ADR 0163).** This is reached from the Settings hub *and* by holding
/// **Loop controls** on the player's status line — which is where you are when you want to change any
/// of these, since all five describe the screen in front of you, and two of them already have chips in
/// that same row. The hold is the shortcut; the Settings row is the findable route, and 0162 is the
/// reason it stays. Both surfaces present *this* view, so there is no second copy of the labels or the
/// ⓘ copy to drift.
///
/// That answers ADR 0162 D9 — the open question of whether these belong on the waveform screen — in
/// favour of *both*, rather than moving them. What it does **not** do is take per-song state with it:
/// `Song.showsGridlines` (ADR 0051) stays a contextual chip on the waveform, so everything in here is
/// global without exception. A "Grid" row sitting beside five sticky preferences would read as sticky
/// too.
struct SongPlayerSettingsView: View {
    // Defaults come from `AppSettings`, never literals — see the note on `transportLoopOnLeftDefault`.
    @AppStorage(AppSettings.Key.transportLoopOnLeft)
    private var transportLoopOnLeft = AppSettings.transportLoopOnLeftDefault
    @AppStorage(AppSettings.Key.waveformMinimapVisible)
    private var waveformMinimapVisible = AppSettings.waveformMinimapVisibleDefault
    @AppStorage(AppSettings.Key.waveformMarkerLabels)
    private var waveformMarkerLabels = AppSettings.waveformMarkerLabelsDefault
    @AppStorage(AppSettings.Key.zoomFollowsPlayhead)
    private var zoomFollowsPlayhead = AppSettings.zoomFollowsPlayheadDefault
    @AppStorage(AppSettings.Key.seekSnapping)
    private var seekSnappingRaw = AppSettings.seekSnappingDefault.rawValue

    private var seekSnapping: Binding<SeekSnapping> {
        Binding(get: { AppSettings.resolvedSeekSnapping(storedValue: seekSnappingRaw) },
                set: { seekSnappingRaw = $0.rawValue })
    }

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

            // How much a seek release catches what is already drawn (ADR 0194). Its own section,
            // and a menu picker rather than a fifth toggle, because it is three values over a
            // considered distinction and not an on/off — see `SeekSnapping`.
            Section {
                Picker("Snap when seeking", selection: seekSnapping) {
                    ForEach(SeekSnapping.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
            } footer: {
                Text("Tapping the waveform lands on the nearest marker, loop edge or beat, so the "
                     + "playhead lines up with what you can see. Dragging already ignores the beats "
                     + "and keeps the markers. Structure only drops the beats from a tap too; Off "
                     + "puts the playhead exactly where you lifted your finger. Loop edges still "
                     + "line up either way.")
            }
        }
        .settingsScreen(title: "Song player")
    }
}

/// `SongPlayerSettingsView` as a sheet, for the hold on the player's Loop control (ADR 0163).
///
/// A wrapper rather than chrome bolted on at the call site, so the waveform screen — which already
/// declares eight presentations — gains one line, and so the sheet form lives next to the screen it
/// presents. Same shape as `MeterPickerSheet`.
struct SongPlayerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SongPlayerSettingsView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(.futura(.body, weight: .bold))
                            .tint(PocketColor.waveformAccent)
                    }
                }
        }
        // Five rows fit the medium detent; `.large` stays available for accessibility text sizes.
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack { SongPlayerSettingsView() }
        .preferredColorScheme(.dark)
}

#Preview("As a sheet") {
    Color.black.sheet(isPresented: .constant(true)) { SongPlayerSettingsSheet() }
        .preferredColorScheme(.dark)
}
