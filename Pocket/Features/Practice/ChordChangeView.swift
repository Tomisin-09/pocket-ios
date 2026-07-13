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
/// absolute beat would let a 4-beat count-in eat the first chord's bar. Instead we anchor `originBeat`
/// the instant `automatorCountdown` clears — the first musical downbeat — and count the progression
/// from there, so chord 1 always gets its full hold starting on beat 1. The surface is shown
/// *throughout* the count-in (chord 1 static, "Get ready"); before the origin is anchored nothing
/// reads as running, so it never disappears during the count and pops back in.
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
                ChordDiagramView(voicing: current, isActive: isRunning, tint: tint)
                    .frame(maxWidth: 190)
                    .animation(.easeInOut(duration: 0.15), value: current)
            }
            if let next {
                VStack(spacing: 6) {
                    Text(isRunning ? "Next" : "Get ready")
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                    ChordDiagramView(voicing: next, isActive: false, tint: tint)
                        .frame(maxWidth: 120)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: index)
        .onChange(of: engine.automatorCountdown) { _, countdown in
            // The count-in just cleared → this beat is the first musical downbeat; anchor the progression.
            if countdown == nil { anchorToDownbeat() }
        }
        .onAppear {
            // No count-in (or already cleared before this appeared) → anchor now; else wait, above.
            if engine.automatorCountdown == nil { anchorToDownbeat() }
        }
    }

    /// Pin the progression's origin to the beat the count-in clears (or on appear when there is none),
    /// so chord 1 gets its full hold starting on the first musical downbeat. Idempotent.
    private func anchorToDownbeat() {
        guard originBeat == nil else { return }
        originBeat = max(0, engine.currentBeat)
    }
}

#Preview("Chord change") {
    ChordChangeView(engine: StandaloneMetronomeEngine(), progression: .gMajorPop)
        .padding()
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
