#if DEBUG
import SwiftUI

/// DEBUG-only Settings scaffold (never ships): A/B the time-stretcher latency correction by ear
/// (ADR 0140 §3).
///
/// Release always compensates — the ADR closes off exposing the stretcher to the player, so this is
/// not a preference and has no shipping counterpart. It exists because the claim being tested is a
/// listening claim: deciding in the absolute whether a click is 93 ms early is hard, while deciding
/// which of two builds is tighter is easy. It also makes the failure case decisive — if
/// `AVAudioEngine` were already compensating node latency internally, "on" would put the click
/// 93–139 ms *late* rather than fixing anything.
///
/// Its own file rather than another block inside `SettingsView`, which is at the 400-line cap.
struct DebugAudioSection: View {

    @AppStorage(AppSettings.Key.compensateStretchLatency) private var compensateStretchLatency = true

    var body: some View {
        Section {
            Toggle("Compensate stretch latency", isOn: $compensateStretchLatency)
        } header: {
            Text("Audio (Debug)")
        } footer: {
            Text("DEBUG only. On is the shipping behaviour: the playhead and the in-song click are "
                 + "pulled back through the time-stretcher's latency so they land on what you hear. "
                 + "Turn it off to hear the uncorrected build. Judge it at 0.25×, where the two "
                 + "differ most — and against a song whose BPM you typed rather than tapped, since "
                 + "a tapped grid has the same offset baked into it.")
        }
    }
}
#endif
