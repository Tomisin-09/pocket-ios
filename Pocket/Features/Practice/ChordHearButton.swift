import SwiftUI

/// The **"Hear" button for a chord voicing** — sounds it as a block chord through the shared
/// `ToneEngine` (ADR 0097) and fires a light haptic. Three call sites (the saved-chord detail, the
/// movable-shape sheet, the custom placer) hand-rolled this button with subtly different action code —
/// one of them silently omitted the haptic. This is the one home for the action, so every Hear affordance
/// behaves the same; only the presentation varies by `style`.
struct ChordHearButton: View {
    /// The voicing to sound. `voicing.midiNotes` already collapses muted/open strings, so a block chord
    /// is exactly the sounded strings.
    let voicing: ChordVoicing
    var style: Style = .prominent
    var tint: Color = PocketColor.practice
    /// When true, the button is disabled (and dimmed, in `.compact`) unless the voicing sounds at least
    /// one string — the custom placer, where an empty grid is a valid in-progress state.
    var gatesOnValidity: Bool = false

    /// The three presentations in use: a full-width filled action (saved-chord detail), a full-width
    /// outlined action (movable sheet), and a compact inline caption button (custom placer, beside the
    /// Display menu).
    enum Style { case prominent, bordered, compact }

    private var isEnabled: Bool { !gatesOnValidity || voicing.isValid }

    var body: some View {
        switch style {
        case .prominent:
            fullWidthButton.buttonStyle(.borderedProminent).tint(tint)
        case .bordered:
            fullWidthButton.buttonStyle(.bordered).tint(tint)
        case .compact:
            compactButton
        }
    }

    private var fullWidthButton: some View {
        Button(action: play) {
            Label("Hear", systemImage: "speaker.wave.2.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .disabled(!isEnabled)
    }

    private var compactButton: some View {
        Button(action: play) {
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2.fill")
                Text("Hear")
            }
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(tint)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel("Hear this chord")
    }

    private func play() {
        ToneEngine.shared.sound(voicing.midiNotes)
        haptic(.light)
    }
}
