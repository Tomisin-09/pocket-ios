import SwiftUI

/// Reusable practice-take record controls (ADR 0069), shared by the run screens (`LoopRunView`,
/// `ExerciseRunView`). Owner-agnostic — they only read/drive the `RecordingController` (arm / route /
/// elapsed); each screen supplies the owner when it begins, stops, or deletes a take. Extracted so
/// the arm toggle, the setup hint, and the live status are styled in one place across surfaces.

/// The slow **record pulse** — the one animation the take controls use, so Reduce Motion is honoured
/// in a single place. Under Reduce Motion the control doesn't merely go static: it holds the pulse's
/// *emphatic* end, so "recording" stays visually distinct from "armed" without any movement.
///
/// `.animation(_:value:)` with a nil-able animation rather than a bare `withAnimation`, which does not
/// reliably cancel a `.repeatForever` — and an uncancelled repeat inside improvise's `Form` keeps the
/// render loop awake for the rest of the screen's life.
struct RecordPulse: ViewModifier {
    /// What pulses: a ring scales, a text label dims (scaled type is harder to read).
    enum Style { case ring, label }

    let active: Bool
    var style: Style = .ring

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var high = false

    func body(content: Content) -> some View {
        content
            .opacity(style == .label && (high || (active && reduceMotion)) ? 0.6 : 1)
            .scaleEffect(style == .ring && high ? 1.06 : 1)
            .animation(active && !reduceMotion
                       ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                       : .easeOut(duration: 0.2),
                       value: high)
            .onChange(of: active, initial: true) { _, isActive in
                high = isActive && !reduceMotion
            }
    }
}

extension View {
    /// Pulse this control while a take is rolling. Decorative only — never let it reach VoiceOver, or
    /// the row re-announces on every cycle.
    func recordPulse(_ active: Bool, style: RecordPulse.Style = .ring) -> some View {
        modifier(RecordPulse(active: active, style: style))
    }
}

/// The **arm toggle** beside Start — three states, because two was a lie. It used to read `isArmed`,
/// which goes *false* the moment a take begins, so the ring reverted to grey exactly when recording
/// started and tapping it did nothing (device pass 2026-08-05).
///
/// - `.idle` — outline ring, grey. Tap requests mic permission on first use.
/// - `.armed` — filled red ring. A take will begin when the run does.
/// - `.recording` — filled red, deeper wash, slowly pulsing.
///
/// `onStopTake` is what a tap does while recording. Non-nil only where the take can end without
/// ending what it was played over — improvise, where the backing track outlives the take. On the
/// ramped run screens it stays `nil`: there a take belongs to the run and ends with it, so the control
/// shows the recording state but isn't a way out of it.
struct RecordArmToggle: View {
    var recorder: RecordingController
    var disabled = false
    var onStopTake: (() -> Void)?

    private var isRecording: Bool { recorder.isRecording }
    private var lit: Bool { recorder.isArmed || isRecording }
    private var tint: Color { lit ? .red : PocketColor.textSecondary }

    var body: some View {
        Button {
            haptic(isRecording ? .medium : .light)
            if isRecording { onStopTake?() } else { Task { await recorder.toggleArm() } }
        } label: {
            Image(systemName: lit ? "record.circle.fill" : "record.circle")
                .font(.futura(.title2))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(Circle().fill(tint.opacity(isRecording ? 0.28 : 0.15)))
                .recordPulse(isRecording)
        }
        .buttonStyle(.plain)
        .disabled(disabled || (isRecording && onStopTake == nil))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityLabel: String {
        if isRecording { return onStopTake == nil ? "Recording" : "Recording — stop and save this take" }
        return recorder.isArmed ? "Recording armed — turn off" : "Record this session"
    }

    private var accessibilityHint: String {
        if isRecording { return onStopTake == nil ? "The take ends when the run does" : "" }
        if recorder.isArmed { return "A take will record when you start training" }
        return disabled ? "Stop the backing track first" : ""
    }
}

/// The **direct take toggle**, for a surface with no Start to arm against (ADR 0069 amendment,
/// 2026-08-05) — a freeform block, whose clock runs from arrival (ADR 0136 F4). One control rather
/// than the two-step: tap to begin a take, tap again to end it. You cannot arm for a Start that does
/// not exist, and the original objection to a mid-run control — fiddling with the screen mid-drill —
/// is about ramped drills running to a schedule; this screen is prose and a clock, and the player is
/// already tapping things on it.
///
/// Owner-agnostic like its siblings: the screen supplies the owner through `action`, which is
/// expected to call `RecordingController.toggleTake(owner:context:)`.
struct RecordTakeToggle: View {
    var recorder: RecordingController
    var action: () -> Void

    var body: some View {
        Button {
            haptic(recorder.isRecording ? .medium : .light)
            action()
        } label: {
            Label(recorder.isRecording ? "Stop recording" : "Record a take",
                  systemImage: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                .font(.futura(.footnote))
                .foregroundStyle(recorder.isRecording ? Color.red : PocketColor.textSecondary)
                .recordPulse(recorder.isRecording, style: .label)
        }
        .accessibilityLabel(recorder.isRecording
                            ? "Recording — stop and save this take"
                            : "Record a take of this block")
    }
}

/// Pre-run guidance under Start: while armed, state *when* it records and nudge toward headphones on a
/// bleed route; if the mic was denied, point at Settings. Nothing when idle.
struct RecordSetupHint: View {
    var recorder: RecordingController
    /// What *this* surface calls its Start, folded into the sentence — "when training starts" on a
    /// ramped run, "when the backing track starts" on improvise, whose button says exactly that. A
    /// parameter rather than a second view: the hint's job is identical on both, and two copies would
    /// drift the headphone nudge apart one fix at a time.
    var startPhrase = "when training starts"

    var body: some View {
        if recorder.isArmed {
            // Always state *when* it records; fold the quality nudge into the same line on a bleed
            // route so it stays one hint, not two (device feedback 2026-07-17).
            Label(recorder.route.isClean
                  ? "Records your playing \(startPhrase)."
                  : "Records \(startPhrase) — headphones give a cleaner take.",
                  systemImage: recorder.route.isClean ? "checkmark.circle" : "headphones")
                .font(.futura(.caption))
                .foregroundStyle(recorder.route.isClean ? PocketColor.practice
                                 : PocketColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
        } else if recorder.micDenied {
            Text("Microphone access is off. Enable it in Settings to record practice takes.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

/// **"Take saved", then "N takes"** — the acknowledgement the open-ended surfaces owe. The player
/// assumed takes were being discarded partly because nothing ever said otherwise (device pass
/// 2026-08-05), so the transient confirmation settles into a durable count: the evidence outlives the
/// moment of capture instead of vanishing with it.
///
/// Deliberately not `UndoToastView` — that requires an `onUndo` and would put an Undo button on a
/// non-destructive event. The controller publishes *what* was saved; the display window lives here.
struct TakeSavedNote: View {
    var recorder: RecordingController
    /// How many takes this owner holds, for the resting line.
    var takeCount: Int
    /// What this surface calls the thing being recorded against — "block" on a freeform exercise,
    /// "loop" on improvise.
    var owner = "block"
    /// Makes the resting count a **way in** to the takes rather than a readout. Non-nil on the
    /// open-ended screens, which have no `PracticeReviewBar` to reach the list from — without it a
    /// take recorded on improvise or ear training is only playable from the Journal tab, which means
    /// leaving the thing you just played over. The count is the obvious place for it: it is already
    /// the sentence that says the takes exist.
    var onOpenTakes: (() -> Void)?

    var body: some View {
        Group {
            if let saved = recorder.lastSaved {
                Label("Take saved · \(RecordingStatusView.takeTime(saved.duration))",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(PocketColor.practice)
                    .transition(.opacity)
            } else if takeCount > 0 {
                countLine
            }
        }
        .font(.futura(.caption))
        .animation(.easeInOut(duration: 0.2), value: recorder.lastSaved)
        // Hold the confirmation for a beat, then let it settle into the count. Keyed on the saved
        // take, so a second take restarts the window rather than inheriting the first one's.
        .task(id: recorder.lastSaved) {
            guard recorder.lastSaved != nil else { return }
            haptic(.success)
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            recorder.clearSavedNote()
        }
    }

    private var countText: String {
        takeCount == 1 ? "1 take on this \(owner)" : "\(takeCount) takes on this \(owner)"
    }

    /// The durable count — a button where the surface can open its takes, plain text where it can't.
    @ViewBuilder private var countLine: some View {
        if let onOpenTakes {
            Button(action: onOpenTakes) {
                // A chevron, not an underline: this reads as a row you can follow, matching the
                // Journal's owner captions rather than looking like body copy someone linked.
                Label(countText, systemImage: "chevron.right")
                    .labelStyle(.trailingChevron)
                    .foregroundStyle(PocketColor.practice)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(countText)
            .accessibilityHint("Listen back to your takes")
        } else {
            Text(countText)
                .foregroundStyle(PocketColor.textSecondary)
        }
    }
}

/// Title first, icon after — for a "follow this" affordance, where the chevron belongs at the end.
private struct TrailingChevronLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.font(.futura(.caption2))
        }
    }
}

private extension LabelStyle where Self == TrailingChevronLabelStyle {
    static var trailingChevron: TrailingChevronLabelStyle { TrailingChevronLabelStyle() }
}

/// The live take status during a run — a red dot + running timer + the route cue. Nothing when not
/// recording.
struct RecordingStatusView: View {
    var recorder: RecordingController

    var body: some View {
        if recorder.isRecording {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Circle().fill(Color.red).frame(width: 10, height: 10)
                    Text(Self.takeTime(recorder.elapsed))
                        .font(.pocketMono(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .contentTransition(.numericText())
                }
                if let nudge = recorder.route.nudge {
                    Text(nudge)
                        .font(.futura(.caption2))
                        .foregroundStyle(PocketColor.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Clean take — just your playing")
                        .font(.futura(.caption2))
                        .foregroundStyle(PocketColor.practice)
                }
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        }
    }

    static func takeTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
