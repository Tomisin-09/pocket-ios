#if DEBUG
import SwiftUI

/// DEBUG-only Settings scaffold (never ships): the two listening A/Bs ADR 0140 is settled by — the
/// latency correction (§3, settled) and the high-quality stretcher (§4, open).
///
/// Neither is a preference. The ADR closes off exposing the stretcher to the player, so both have a
/// fixed Release behaviour and no shipping counterpart. They exist because the claims are *listening*
/// claims, and a human judges "which of these two is better" far more reliably than "is this one
/// right" — which is also what makes each failure case decisive rather than ambiguous.
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
