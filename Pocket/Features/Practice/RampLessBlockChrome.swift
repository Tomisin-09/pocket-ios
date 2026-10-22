import SwiftUI
import UIKit

/// The **block chrome for a block with no ramp** (ADR 0141, 0271) — the planned length, the end-of-block
/// advance, and the one bar along the bottom that holds the remaining-time readout and the block's
/// **Done**. Applied by `EarLoopRunView` (ADR 0104), `ImproviseLoopRunView` (ADR 0135) and
/// `FreeformRunView` (ADR 0136).
///
/// **A budget, not a buzzer** (L2). Nothing here stops audio, disables Done, or interrupts a phrase:
/// when the planned time is up the modifier waits for the current loop region to come round
/// (`RampLessBlockLength.finishTime`) and *then* advances the session, the same way a finished ramp
/// advances it. A block with no planned length — one that declined the fit (ADR 0130), or a
/// standalone screen with no routine at all — never fires, which is the ADR 0104 / 0135 behaviour
/// preserved exactly as a choice rather than as the only option (L4).
///
/// The readout is deliberately plain (L3): `m:ss left`, in the secondary text colour, no urgency and
/// no colour change at zero — set large enough to read at a glance (ADR 0271 D7). The player who wants to know looks; the player who doesn't isn't chased.
///
/// **The top band is the routine; this bar is the block** (ADR 0271). Done used to sit top right, where
/// iOS puts the button that closes the whole modal, beside ✕ and the progress strip that both act on the
/// routine. Down here it sits with the one other thing about this block that matters while it runs: how
/// long is left before it moves on by itself. The bar has a background, so a Form scrolling under it
/// (Save to Journal, on an ear or improvise block) stays legible rather than having the readout drawn on
/// top of it.
struct RampLessBlockChrome: ViewModifier {
    /// The block's resolved length in minutes, or `nil` for open-ended. Comes from the routine
    /// context, which `RoutineSessionPlayer` has already run through ADR 0141's three-way rule.
    let plannedMinutes: Int?
    /// How long one pass of the loop region currently takes — read live, since the player can change
    /// the tempo mid-block and a slower rate makes a longer cycle.
    let cycleSeconds: () -> TimeInterval
    /// Whether audio is sounding right now. Nothing playing means no phrase to protect.
    let isPlaying: () -> Bool
    /// The block's Done, or `nil` on a screen with nothing to finish into.
    let done: BlockDone?
    /// Natural completion — the same seam Done calls, so a block that runs its length logs and
    /// advances exactly as one the player finished by hand.
    let onFinish: () -> Void

    /// When the block began. Set on appearance rather than on a transport action: these screens have
    /// no Start, the loop plays from arrival (ADR 0104).
    @State private var startedAt = Date.now
    /// When audio last started sounding, for the cycle-boundary rounding. `nil` while silent.
    @State private var playbackStartedAt: Date?
    @State private var now = Date.now
    /// Latched so a re-fired tick can't advance the session twice, nor fire after Done already has.
    @State private var finished = false
    /// Done steps aside while the keyboard is up (ADR 0271 D5). The bar rides on top of the keyboard,
    /// which would put Done right under the keyboard's dismiss checkmark (`KeyboardDismissAccessory`),
    /// one mistap from ending the block mid-note. The time left stays: typing a note is exactly when
    /// the player most needs warning that the block is about to move on without them.
    @State private var keyboardUp = false

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
            .safeAreaInset(edge: .bottom, spacing: 0) { bar }
            .onReceive(tick) { instant in
                now = instant
                trackPlayback()
                advanceIfDue()
            }
            .onAppear { trackPlayback() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardUp = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardUp = false
            }
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

    /// Done while the keyboard is down; see `keyboardUp`.
    private var shownDone: BlockDone? { keyboardUp ? nil : done }

    /// The readout on the leading edge, Done on the trailing one. Done keeps its corner whether or not
    /// there is a readout beside it, so it is in the same place on every ramp-less block. With neither —
    /// an open-ended block with Done stepped aside, or on a screen with no Done — there is no bar.
    @ViewBuilder private var bar: some View {
        if remainingLabel != nil || shownDone != nil {
            HStack(spacing: 12) {
                if let remainingLabel {
                    // Callout semibold, not caption (ADR 0271 D7): beside a bordered Done the caption read
                    // as too light on the device. Still the secondary colour — easier to read, not urgent.
                    Text(remainingLabel)
                        .font(.pocketMono(.callout).weight(.semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .monospacedDigit()
                        .accessibilityLabel("\(remainingLabel) in this block")
                }
                Spacer(minLength: 0)
                if let shownDone {
                    doneButton(shownDone)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider() }
        }
    }

    /// Quiet, not a call to action (ADR 0104 S2.6): a full-width pill read like something had gone
    /// wrong. **Never disabled** (ADR 0141 L2) — finishing early was always the design.
    private func doneButton(_ done: BlockDone) -> some View {
        Button {
            haptic(.light)
            finished = true     // the clock must not advance a second time behind it
            onFinish()
        } label: {
            Text(done.title)
                .font(.futura(.body, weight: .semibold))
                .padding(.horizontal, 6)
        }
        .buttonStyle(.bordered)
        .tint(PocketColor.practice)
        .accessibilityLabel(done.accessibilityLabel)
    }
}

/// What a ramp-less block's Done says, to the eye and to VoiceOver.
struct BlockDone {
    /// **Done**, or **Finish** on a routine's last block (`RoutineRunContext.finishTitle`).
    let title: String
    /// Says *which* thing is done — the block, not the routine.
    let accessibilityLabel: String
}

extension View {
    /// Give a ramp-less block its planned length (ADR 0141) and its bottom bar (ADR 0271). The length
    /// is a no-op outside a routine, and on a block that declined the fit — both arrive here as a `nil`
    /// `plannedMinutes`.
    func rampLessBlockLength(plannedMinutes: Int?,
                             cycleSeconds: @escaping () -> TimeInterval,
                             isPlaying: @escaping () -> Bool,
                             done: BlockDone?,
                             onFinish: @escaping () -> Void) -> some View {
        modifier(RampLessBlockChrome(plannedMinutes: plannedMinutes, cycleSeconds: cycleSeconds,
                                     isPlaying: isPlaying, done: done, onFinish: onFinish))
    }
}
