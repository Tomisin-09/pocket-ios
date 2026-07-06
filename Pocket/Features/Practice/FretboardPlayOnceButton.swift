import SwiftUI

/// A one-shot "watch it" button (ADR 0065): plays a single walk-through of the paired
/// `FretboardDrillPreview` regardless of the global animate preference or Reduce Motion — a
/// deliberate, user-requested pass is a different thing from sustained flashing, so it isn't gated the
/// way the always-on highlight is. Bind `playToken` to the same state passed as that preview's
/// `playOnceToken`.
struct FretboardPlayOnceButton: View {
    @Binding var playToken: Date?
    var tint: Color = PocketColor.practice

    var body: some View {
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
