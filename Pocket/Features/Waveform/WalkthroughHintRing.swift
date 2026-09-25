import SwiftUI

/// The walkthrough's pointer at a control (ADR 0220 D3, D4): a ring that breathes, or holds still
/// under Reduce Motion. Drawn outside the control and never hit-tested, so it cannot take the tap it
/// is asking for.
///
/// One ring for every pointer the first session makes — Loop (beat 1), the metronome and the kept
/// loop's row (the two hints) — so the player learns what it means once. It takes the colour of the
/// thing it rings, and the shape: a circle round a circular control, a rounded rectangle round a row.
struct HintRing<RingShape: Shape>: View {
    let color: Color
    let shape: RingShape
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        shape
            .stroke(color, lineWidth: 2.5)
            .opacity(dimmed ? 0.35 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dimmed = true }
            }
    }
}

extension HintRing where RingShape == Circle {
    init(color: Color) { self.init(color: color, shape: Circle()) }
}
