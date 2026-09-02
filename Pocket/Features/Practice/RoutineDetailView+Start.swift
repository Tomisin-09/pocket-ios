import SwiftData
import SwiftUI

/// The routine's **Start** bar (ADR 0066/0071), split out of `RoutineDetailView` to keep that file
/// under the 400-line cap. The run entry point, as distinct from everything else on that screen,
/// which is about authoring.
extension RoutineDetailView {

    /// The bottom **Start** button that launches the player — the primary action once a routine is
    /// built. Shown only in read-only mode (editing has Save/Cancel instead) and only when there's
    /// something runnable. Pinned to the bottom via `safeAreaInset` so it floats over the block
    /// list; every routine detail screen carries it.
    @ViewBuilder
    var startBar: some View {
        if !isEditing && hasPlayableBlock {
            Button(action: startPlaying) {
                Label("Start", systemImage: "play.fill")
                    .font(.futura(.body, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PocketColor.practice, in: Capsule())
                    .foregroundStyle(PocketColor.background)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .accessibilityLabel("Start routine")
        }
    }

    /// Start the session in the player. A **provisional** generated session is committed first
    /// (Start is a deliberate keep, and running must write real practice history), then resolved into
    /// the main context so its run screens write to the real store — not this view's editing sandbox.
    private func startPlaying() {
        if !existsInStore { commitProvisional(named: routine.name) }
        playingRoutine = appContext.model(for: routine.persistentModelID) as? Routine
        haptic(.medium)
    }
}
