import SwiftUI

/// The **live chord-changing surface** over the shared metronome clock (ADR 0065): the current
/// chord's diagram, large, with the next chord previewed small beside it, swapping on the beat as
/// the click runs. Unlike the fretboard/strum walking highlights this carries no flashing motion —
/// a chord held for a whole bar is the *content*, not decoration — so it isn't gated by the animate
/// preference; it simply reads which chord is active from the pure `ChordProgression` timing.
///
/// The engine publishes integer beats, which is all a per-bar change needs: reading
/// `engine.currentBeat` in `body` re-renders each beat, and the pure `activeIndex(atBeat:)` decides
/// the chord.
///
/// **Count-in is decoupled from the progression.** The engine's `currentBeat` counts *through* the
/// count-in (it doesn't reset at the first musical beat), so measuring the progression from the
/// absolute beat would let a 4-beat count-in eat the first chord's bar. Instead we anchor to the beat
/// the surface first appears — which is the first musical downbeat, since the run screen only mounts
/// this view once `automatorCountdown` clears — and count the progression from there, so chord 1
/// always gets its full hold starting on beat 1.
struct ChordChangeView: View {
    let engine: StandaloneMetronomeEngine
    let progression: ChordProgression
    var tint: Color = PocketColor.practice

    /// The engine beat at which this surface began (the first post-count-in downbeat), captured once.
    @State private var originBeat: Int?

    /// The active change index, measured from the anchored origin, or `nil` before it's anchored.
    private var activeIndex: Int? {
        guard let origin = originBeat else { return nil }
        return progression.activeIndex(atBeat: Double(engine.currentBeat - origin))
    }

    var body: some View {
        let index = activeIndex ?? 0
        let current = progression.change(at: index)?.voicing
        let next = progression.nextIndex(after: index).flatMap { progression.change(at: $0)?.voicing }
        let isRunning = activeIndex != nil

        return HStack(alignment: .top, spacing: 24) {
            if let current {
                ChordDiagramView(voicing: current, isActive: isRunning, tint: tint,
                                 degreeLabel: progression.numeral(for: current))
                    .frame(maxWidth: 190)
                    .animation(.easeInOut(duration: 0.15), value: current)
            }
            if let next {
                VStack(spacing: 6) {
                    Text(isRunning ? "Next" : "Get ready")
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                    ChordDiagramView(voicing: next, isActive: false, tint: tint,
                                     degreeLabel: progression.numeral(for: next))
                        .frame(maxWidth: 120)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: index)
        .onAppear { if originBeat == nil { originBeat = max(0, engine.currentBeat) } }
    }
}

#Preview("Chord change") {
    ChordChangeView(engine: StandaloneMetronomeEngine(), progression: .gMajorPop)
        .padding()
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
