import SwiftUI

/// A hairline progress track for an exercise's working-tempo-vs-goal climb (ADR 0043, slice
/// 7). A quiet capsule that fills left→right by `fraction` (`0...1`) in the metronome tint —
/// shared by the main-screen progress chip and each library row so the climb reads the same
/// in both places.
struct TempoProgressBar: View {
    let fraction: Double
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PocketColor.textSecondary.opacity(0.2))
                Capsule()
                    .fill(PocketColor.metronome)
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
