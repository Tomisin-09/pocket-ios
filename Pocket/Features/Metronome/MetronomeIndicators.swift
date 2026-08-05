import SwiftUI

/// A dot per click in the bar; the current click lights up and the meter's **accented**
/// clicks read in the metronome colour and a touch larger. A standalone view (split from
/// `MetronomeView`) so the engine's per-tick `currentBeat` updates re-render only the dots,
/// not the whole screen (which would dismiss the time-signature menu mid-play).
struct BeatIndicator: View {
    let engine: StandaloneMetronomeEngine
    /// The accent-dot colour — defaults to the metronome tint, overridden to `PocketColor.practice`
    /// on the Practice run screens so the count-in dots read in that space's colour, not teal.
    var tint: Color = PocketColor.metronome

    var body: some View {
        // The dots **read the level the click was voiced at** (ADR 0132 §7) rather than separately
        // deciding when to go dark, so the visual and the audible cannot diverge: a `downbeatOnly`
        // bar lights beat 1 and nothing else, because that is what sounded. If the dots kept flashing
        // through a withdrawn bar the feature would be a no-op for anyone looking at the screen — it
        // would move the crutch from the ear to the eye, and a visual metronome is a metronome.
        //
        // They stay *visible*, dimmed and unlit. Chrome that disappears reads as a failure, and this
        // project has had real audio-session deaths where the click genuinely stopped; present and
        // deliberately quiet is the difference between "the app is listening" and "the app is dead".
        let withdrawal = engine.heardWithdrawalLevel
        HStack(spacing: 10) {
            ForEach(0..<engine.timeSignature.beats, id: \.self) { index in
                let isCurrent = engine.isPlaying
                    && engine.currentBeat % engine.timeSignature.beats == index
                    && sounds(beatInBar: index, under: withdrawal)
                let isAccent = engine.timeSignature.isAccented(beatInBar: index)
                Circle()
                    .fill(dotColor(isCurrent: isCurrent, isAccent: isAccent))
                    .frame(width: isAccent ? 18 : 14, height: isAccent ? 18 : 14)
                    .scaleEffect(isCurrent ? 1.4 : 1.0)
                    .animation(.easeOut(duration: 0.07), value: engine.currentBeat)
            }
        }
        .frame(height: 32)
        .accessibilityHidden(true)
    }

    /// Whether the click sounded on this beat of the bar under the withdrawal currently in force.
    private func sounds(beatInBar index: Int, under level: ClickWithdrawal.Level) -> Bool {
        switch level {
        case .full: return true
        case .downbeatOnly: return index == 0
        case .silent: return false
        }
    }

    private func dotColor(isCurrent: Bool, isAccent: Bool) -> Color {
        if isCurrent { return isAccent ? tint : PocketColor.textPrimary }
        return isAccent ? tint.opacity(0.4) : PocketColor.textSecondary.opacity(0.4)
    }
}
