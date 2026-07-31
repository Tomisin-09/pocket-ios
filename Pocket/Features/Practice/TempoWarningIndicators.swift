import SwiftUI

/// The two **visual carriers** of the tempo-change warning (ADR 0131 §3 / §3a) — the run caption and
/// the drill-surface edge.
///
/// Both are deliberately tiny standalone views, for the reason `BeatIndicator` is: reading the warning
/// touches `automatorBarsElapsed`, which the driver advances every ~20 ms, so whichever view reads it
/// re-renders at tick rate. Kept small, that costs a `Text` and a stroked rectangle; folded into a run
/// screen's `body` it would re-render the drill surface fifty times a second.

/// The run screen's tempo caption, which becomes the warning while one is showing. This is the
/// **accessible** carrier — the edge and the staircase pre-light are both silent to VoiceOver — so the
/// warning is carried as text here, not colour alone.
struct TempoWarningCaption: View {
    let engine: StandaloneMetronomeEngine
    /// What the caption reads when nothing is being warned about — the ordinary "BPM · Andante · ♪"
    /// line the screen shows the rest of the time.
    let fallback: String

    var body: some View {
        let warning = engine.tempoWarning
        Text(warning?.caption ?? fallback)
            .font(.futura(.caption))
            .foregroundStyle(warning == nil ? PocketColor.textSecondary : PocketColor.practice)
    }
}

/// The edge the drill surface takes for the duration of the warning window.
///
/// **Static, and that is the decision** (ADR 0131 §3a): a pulse would fall under Reduce Motion and
/// `exerciseAnimates` — which defaults *off* as a photosensitivity precaution — so an animated carrier
/// would be disabled by default for exactly the players it is meant to serve. A state change that does
/// not animate is governed by neither.
///
/// The colour is the Practice space's own teal, because the signal is the edge's **presence**, not its
/// hue: the drill surfaces carry no border at all the rest of the time, so its appearing is already
/// unambiguous. That also means colour vision isn't needed to read it, and no other space's identity
/// (metronome plum, marker orange) has to be borrowed onto a Practice screen.
struct TempoWarningEdge: View {
    let engine: StandaloneMetronomeEngine
    var tint: Color = PocketColor.practice

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(tint, lineWidth: 2)
            .opacity(engine.tempoWarning == nil ? 0 : 1)
            .allowsHitTesting(false)
            // The caption states the same thing in words; announcing the edge too would read the
            // warning twice.
            .accessibilityHidden(true)
    }
}
