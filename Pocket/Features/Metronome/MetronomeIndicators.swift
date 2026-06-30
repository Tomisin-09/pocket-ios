import SwiftUI

/// A dot per click in the bar; the current click lights up and the meter's **accented**
/// clicks read in the metronome colour and a touch larger. A standalone view (split from
/// `MetronomeView`) so the engine's per-tick `currentBeat` updates re-render only the dots,
/// not the whole screen (which would dismiss the time-signature menu mid-play).
struct BeatIndicator: View {
    let engine: StandaloneMetronomeEngine

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<engine.timeSignature.beats, id: \.self) { index in
                let isCurrent = engine.isPlaying
                    && engine.currentBeat % engine.timeSignature.beats == index
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

    private func dotColor(isCurrent: Bool, isAccent: Bool) -> Color {
        if isCurrent { return isAccent ? PocketColor.metronome : PocketColor.textPrimary }
        return isAccent ? PocketColor.metronome.opacity(0.4) : PocketColor.textSecondary.opacity(0.4)
    }
}

/// The running session time — ephemeral wall-clock that keeps running through tempo
/// changes and resets on stop (ADR 0043). A standalone view so its per-second update
/// doesn't re-render the controls. Used on the Practice **exercise run** screen; the
/// standalone metronome screen dropped it (too much space for too little payoff).
struct SessionTracker: View {
    let engine: StandaloneMetronomeEngine

    var body: some View {
        VStack(spacing: 2) {
            Text("SESSION")
                .font(.caption2.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(PocketColor.textSecondary)
            Text(timecode(engine.elapsed))
                .font(.pocketMono(.title))
                .foregroundStyle(engine.transport == .stopped
                                 ? PocketColor.textSecondary : PocketColor.textPrimary)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session time \(timecode(engine.elapsed))")
    }
}
