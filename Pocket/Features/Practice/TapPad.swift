import SwiftUI

/// The tap pad (ADR 0225 D2), for counting a pass and, in Name the notes, for tapping in a note that was
/// missed (ADR 0231): one gesture for both, so a note added later is placed the way it would have been
/// counted.
///
/// Fires on **touch-down**, not on lift: a `Button` or `onTapGesture` fires as the finger leaves the
/// glass, which adds a lag that varies with how long each tap is held. A zero-distance drag latches on the
/// first contact instead, the way `StepperButton` does (and it's not a `Button` at all, memory: a Button
/// with a second gesture fires both).
struct TapPad: View {

    /// What the pad says: its title, the title while it says why a tap didn't take, and the caption live
    /// and idle.
    struct Words {
        let title: String
        let nudge: String
        let live: String
        let idle: String
        let accessibility: String
        let identifier: String

        static let count = Words(title: "Tap each note", nudge: "Press play first",
                                 live: "Once for every note you hear",
                                 idle: "Counting starts once the loop plays",
                                 accessibility: "Tap once for each note you hear", identifier: "count.pad")

        /// *Missed a note?* in Name the notes: one tap, while the stretch plays.
        static func missed(_ noun: String) -> Words {
            Words(title: "Tap the \(noun) you missed", nudge: "Play it first",
                  live: "Once, where you hear it", idle: "Play it again, then tap where you hear it",
                  accessibility: "Tap where you hear the \(noun) you missed", identifier: "naming.missedPad")
        }
    }

    let words: Words
    let isLive: Bool
    let flashToken: Int
    let nudgeToken: Int
    var height: CGFloat = 118
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var flashing = false
    @State private var nudging = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(flashing ? PocketColor.practice.opacity(0.35) : PocketColor.surfaceStandard)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(PocketColor.surfaceBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .overlay {
                VStack(spacing: 2) {
                    Text(nudging ? words.nudge : words.title)
                        .font(.futura(.title3))
                        .foregroundStyle(isLive ? PocketColor.textPrimary : PocketColor.textSecondary)
                    Text(isLive ? words.live : words.idle)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            }
            .frame(height: height)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onTap()
                    }
                    .onEnded { _ in isPressed = false }
            )
            .onChange(of: flashToken) {
                haptic(.light)
                flashing = true
                withAnimation(.easeOut(duration: 0.18)) { flashing = false }
            }
            .task(id: nudgeToken) {
                guard nudgeToken > 0 else { return }
                nudging = true
                try? await Task.sleep(for: .seconds(1.1))
                nudging = false
            }
            .onAppear { prepareHaptics() }
            .accessibilityElement()
            .accessibilityLabel(words.accessibility)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(words.identifier)
            .accessibilityAction { onTap() }
    }
}
