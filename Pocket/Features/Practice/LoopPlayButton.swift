import SwiftUI

/// Starting and stopping a looping bed, the one way every play button does it (ADR 0069 slice 2): an armed
/// take begins **before** the audio does, while nothing is sounding, and a take is finished **before** the
/// audio stops, since the engine releases the shared session on stop. The big button in
/// `ContinuousLoopControls` and Count the notes' small one (ADR 0234 D2) both call this, so they can't come
/// to behave differently.
@MainActor
enum LoopTransport {
    static func toggle(_ player: ContinuousLoopPlayer, recorder: RecordingController?, onStopped: () -> Void) {
        haptic(.light)
        if player.isPlaying {
            onStopped()
            player.toggle()
        } else {
            recorder?.beginArmedTake()
            player.toggle()
        }
    }
}

/// The **small play button**: a 30-point circle in a 44-point target, ▶ or ■, and a spinner while the
/// audio loads. Name the notes' strip plays the loop with it (ADR 0227 D2). Count the notes puts one beside
/// *Show beats* (ADR 0234 D2), so the loop starts from where the counting is, not from the big button a
/// scroll above it. *Watch it on the neck* draws it larger (ADR 0254), as the one control in its row.
struct LoopPlayButton: View {
    /// Filled with ■ while something plays.
    let isOn: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let label: String
    /// The circle's size. Never touched at less than 44 points, however small it's drawn.
    var diameter: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isOn ? PocketColor.practice : PocketColor.practice.opacity(0.14))
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: isOn ? "stop.fill" : "play.fill")
                        .font(.system(size: diameter * 0.4, weight: .bold))
                        .foregroundStyle(isOn ? PocketColor.background : PocketColor.practice)
                        .offset(x: isOn ? 0 : 1)   // optical-centre the play triangle
                }
            }
            .frame(width: diameter, height: diameter)
            .frame(width: max(diameter, 44), height: max(diameter, 44))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(label)
    }
}
