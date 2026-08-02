import SwiftUI

/// The **routine chrome for a block with no ramp** (ADR 0141) — the planned length, the quiet
/// remaining-time readout, and the end-of-block advance. Applied by `EarLoopRunView` (ADR 0104) and
/// `ImproviseLoopRunView` (ADR 0135), which are otherwise the same screen with different copy.
///
/// **A budget, not a buzzer** (L2). Nothing here stops audio, disables Done, or interrupts a phrase:
/// when the planned time is up the modifier waits for the current loop region to come round
/// (`RampLessBlockLength.finishTime`) and *then* advances the session, the same way a finished ramp
/// advances it. A block with no planned length — one that declined the fit (ADR 0130), or a
/// standalone screen with no routine at all — never fires, which is the ADR 0104 / 0135 behaviour
/// preserved exactly as a choice rather than as the only option (L4).
///
/// The readout is deliberately plain (L3): `m:ss left`, in the secondary text colour, no urgency and
/// no colour change at zero. The player who wants to know looks; the player who doesn't isn't chased.
struct RampLessBlockChrome: ViewModifier {
    /// The block's resolved length in minutes, or `nil` for open-ended. Comes from the routine
    /// context, which `RoutineSessionPlayer` has already run through ADR 0141's three-way rule.
    let plannedMinutes: Int?
    /// How long one pass of the loop region currently takes — read live, since the player can change
    /// the tempo mid-block and a slower rate makes a longer cycle.
    let cycleSeconds: () -> TimeInterval
    /// Whether audio is sounding right now. Nothing playing means no phrase to protect.
    let isPlaying: () -> Bool
    /// Natural completion — the same seam the block's own Done button uses, so a block that runs its
    /// length logs and advances exactly as one the player finished by hand.
    let onFinish: () -> Void

    /// When the block began. Set on appearance rather than on a transport action: these screens have
    /// no Start, the loop plays from arrival (ADR 0104).
    @State private var startedAt = Date.now
    /// When audio last started sounding, for the cycle-boundary rounding. `nil` while silent.
    @State private var playbackStartedAt: Date?
    @State private var now = Date.now
    /// Latched so a re-fired tick can't advance the session twice.
    @State private var finished = false

    /// One second is enough for a countdown that shows whole seconds, and cheap enough to leave
    /// running for the length of a block.
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var plannedEnd: Date? {
        RampLessBlockLength.seconds(plannedMinutes: plannedMinutes, usesAuthoredLength: false,
                                    fallback: nil)
            .map { startedAt.addingTimeInterval($0) }
    }

    private var remainingLabel: String? {
        RampLessBlockLength.remainingLabel(elapsed: now.timeIntervalSince(startedAt),
                                           planned: plannedEnd?.timeIntervalSince(startedAt))
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) { readout }
            .onReceive(tick) { instant in
                now = instant
                trackPlayback()
                advanceIfDue()
            }
            .onAppear { trackPlayback() }
    }

    /// Remember when the current stretch of playback began — the anchor cycle boundaries are counted
    /// from. Cleared on stop so a pause doesn't leave a stale anchor behind.
    private func trackPlayback() {
        if isPlaying() {
            if playbackStartedAt == nil { playbackStartedAt = now }
        } else {
            playbackStartedAt = nil
        }
    }

    private func advanceIfDue() {
        guard !finished, let plannedEnd else { return }
        let deadline = RampLessBlockLength.finishTime(plannedEnd: plannedEnd,
                                                      playbackStart: playbackStartedAt,
                                                      cycleSeconds: cycleSeconds())
        guard now >= deadline else { return }
        finished = true
        onFinish()
    }

    @ViewBuilder private var readout: some View {
        if let remainingLabel {
            Text(remainingLabel)
                .font(.pocketMono(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .monospacedDigit()
                .padding(.bottom, 6)
                .accessibilityLabel("\(remainingLabel) in this block")
        }
    }
}

extension View {
    /// Give a ramp-less routine block its planned length (ADR 0141). No-op outside a routine, and on
    /// a block that declined the fit — both arrive here as a `nil` `plannedMinutes`.
    func rampLessBlockLength(plannedMinutes: Int?,
                             cycleSeconds: @escaping () -> TimeInterval,
                             isPlaying: @escaping () -> Bool,
                             onFinish: @escaping () -> Void) -> some View {
        modifier(RampLessBlockChrome(plannedMinutes: plannedMinutes, cycleSeconds: cycleSeconds,
                                     isPlaying: isPlaying, onFinish: onFinish))
    }
}
