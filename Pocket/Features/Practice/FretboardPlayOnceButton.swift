import SwiftUI

/// A one-shot "watch it" button (ADR 0065, gating reversed by ADR 0077): plays a single walk-through
/// of the paired `FretboardDrillPreview`. It **hides itself when the board is already walking
/// continuously** — i.e. the animate-exercises preference is on *and* Reduce Motion is off — because a
/// one-shot is redundant there. It **shows** when animation is off or Reduce Motion is on, which is
/// exactly when a deliberate, user-requested pass is the only way to see the shape move (the
/// motion-averse escape hatch). Bind `playToken` to the same state passed as that preview's
/// `playOnceToken`.
struct FretboardPlayOnceButton: View {
    @Binding var playToken: Date?
    var tint: Color = PocketColor.practice
    /// The animate-exercises preference — read so Watch can hide when the board already walks
    /// (ADR 0077). Mirrors `FretboardDrillPreview`'s own `@AppStorage`.
    @AppStorage(AppSettings.Key.exerciseAnimates) private var animates = AppSettings.exerciseAnimatesDefault
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if Self.shouldShow(animates: animates, reduceMotion: reduceMotion) {
            Button {
                playToken = Date()
                haptic(.light)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.circle")
                    Text("Watch")
                }
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(tint)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Watch the shape")
            .accessibilityHint("Plays a single walk-through of the run")
        }
    }

    /// Whether Watch should be shown (ADR 0077). The board walks continuously only when the animate
    /// preference is on **and** Reduce Motion is off; in that case the one-shot is redundant, so hide
    /// it. Otherwise (animation off, or Reduce Motion forcing the board static) show it — it's the
    /// only way to see the shape move. Pure and `nonisolated` so it's unit-testable synchronously
    /// from a non-main-actor context (the view itself is main-actor-isolated; CI's Swift 6 strict
    /// concurrency rejects calling a main-actor static method from XCTest otherwise).
    nonisolated static func shouldShow(animates: Bool, reduceMotion: Bool) -> Bool {
        !(animates && !reduceMotion)
    }
}

#Preview("Play once button") {
    struct Harness: View {
        @State private var token: Date?
        var body: some View {
            VStack(spacing: 16) {
                FretboardPlayOnceButton(playToken: $token)
                FretboardDrillPreview(drill: .spiderWalk, playOnceToken: token)
            }
            .padding()
        }
    }
    return Harness()
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
