import SwiftUI

/// The two **visual carriers** of the tempo-change warning (ADR 0131 §3 / §3a) — the run caption and
/// the drill-surface edge. The caption is shared with ADR 0132's click withdrawal, which needs the same
/// one line; see `RunTempoCaption` for the precedence between them.
///
/// Both are deliberately tiny standalone views, for the reason `BeatIndicator` is: reading the warning
/// touches `automatorBarsElapsed`, which the driver advances every ~20 ms, so whichever view reads it
/// re-renders at tick rate. Kept small, that costs a `Text` and a stroked rectangle; folded into a run
/// screen's `body` it would re-render the drill surface fifty times a second.

/// The run screen's tempo caption — one line under the BPM, and therefore **one slot with three
/// possible occupants**, which is why their precedence is resolved here rather than by each feature
/// deciding separately whether to appear.
///
/// This is the **accessible** carrier for both features that use it. ADR 0131's edge and staircase
/// pre-light are silent to VoiceOver, and ADR 0132's `BeatIndicator` is `accessibilityHidden(true)`,
/// so without a word here a screen-reader user gets an unannounced tempo change or an unexplained
/// silence. Text, not colour alone, in both cases.
///
/// **The warning outranks the withdrawal** (ADR 0131 §6): a warning bar is never silenced, so when a
/// change is being announced the caption announces it. Since ADR 0132's amendment the two can no
/// longer collide — a warning needs a running ramp, and a running ramp suspends the withdrawal — so
/// the order below is belt-and-braces rather than load-bearing. It is stated anyway, because the thing
/// keeping them apart is a rule in `ClickWithdrawal.resolve` that a later slice could relax.
struct RunTempoCaption: View {
    let engine: StandaloneMetronomeEngine
    /// What the caption reads when neither feature has anything to say — the ordinary
    /// "BPM · Andante · ♪" line the screen shows the rest of the time.
    let fallback: String
    /// The colour a *warning* takes; the withdrawal word stays in the ordinary caption colour, being
    /// a standing state rather than an event to react to.
    var tint: Color = PocketColor.practice

    var body: some View {
        let warning = engine.tempoWarning
        Text(warning?.caption ?? engine.heardWithdrawalLevel.caption ?? fallback)
            .font(.futura(.caption))
            .foregroundStyle(warning == nil ? PocketColor.textSecondary : tint)
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
