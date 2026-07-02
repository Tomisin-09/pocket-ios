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
