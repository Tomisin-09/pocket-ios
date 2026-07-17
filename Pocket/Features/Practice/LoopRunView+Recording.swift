import SwiftUI

/// Practice-take recording on the loop trainer (ADR 0069, slice 2). Recording is a **pre-start arm
/// toggle** beside Start training (off by default) — device feedback (2026-07-17): asking the player
/// to hit record mid-run is a focus tax, and flipping the session mid-play glitched the audio. Armed,
/// the take begins with the run (after the count-in) and stops when the run does; the mic captures
/// only the player. Kept in its own extension so `LoopRunView` stays lean; lifecycle lives on
/// `RecordingController`.
extension LoopRunView {

    /// The arm toggle beside Start — an outline record ring when off, a filled red ring when armed.
    /// Tapping it requests mic permission on first use (on this setup screen, not during the run).
    var recordArmToggle: some View {
        Button { Task { await recorder.toggleArm() } } label: {
            Image(systemName: recorder.isArmed ? "record.circle.fill" : "record.circle")
                .font(.futura(.title2))
                .foregroundStyle(recorder.isArmed ? Color.red : PocketColor.textSecondary)
                .frame(width: 56, height: 56)
                .background(Circle().fill((recorder.isArmed ? Color.red
                                           : PocketColor.textSecondary).opacity(0.15)))
        }
        .buttonStyle(.plain)
        .disabled(model.isLoading || model.loadFailed)
        .accessibilityLabel(recorder.isArmed ? "Recording armed — turn off"
                            : "Record this session")
        .accessibilityHint(recorder.isArmed ? "A take will record when you start training" : "")
    }

    /// Pre-run guidance shown under Start: while armed, confirm what will happen and nudge toward
    /// headphones on a bleed route; if the mic was denied, point at Settings. Nothing when idle.
    @ViewBuilder var recordSetupHint: some View {
        if recorder.isArmed {
            // Always state *when* it records (device feedback 2026-07-17: the arm isn't live yet);
            // fold the quality nudge into the same line on a bleed route so it stays one hint, not two.
            Label(recorder.route.isClean
                  ? "Records your playing when training starts."
                  : "Records when training starts — headphones give a cleaner take.",
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

    /// The live take status during a run — a red dot + running timer + the route cue. Nothing when
    /// not recording.
    @ViewBuilder var recordingStatus: some View {
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

    /// Finalize an in-flight take when the run ends or the screen exits, so a take is never left
    /// recording after the audio it was played over has stopped. Idempotent.
    func finishTakeIfNeeded() {
        recorder.finishIfRecording(owner: .loop(loop), context: modelContext)
    }

    static func takeTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
