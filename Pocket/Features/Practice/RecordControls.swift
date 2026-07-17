import SwiftUI

/// Reusable practice-take record controls (ADR 0069), shared by the run screens (`LoopRunView`,
/// `ExerciseRunView`). Owner-agnostic — they only read/drive the `RecordingController` (arm / route /
/// elapsed); each screen supplies the owner when it begins, stops, or deletes a take. Extracted so
/// the arm toggle, the setup hint, and the live status are styled in one place across surfaces.

/// The pre-start **arm toggle** beside Start — an outline record ring when off, a filled red ring
/// when armed. Tapping requests mic permission on first use (on the setup screen, not during the run).
struct RecordArmToggle: View {
    var recorder: RecordingController
    var disabled = false

    var body: some View {
        Button {
            haptic(.light)
            Task { await recorder.toggleArm() }
        } label: {
            Image(systemName: recorder.isArmed ? "record.circle.fill" : "record.circle")
                .font(.futura(.title2))
                .foregroundStyle(recorder.isArmed ? Color.red : PocketColor.textSecondary)
                .frame(width: 56, height: 56)
                .background(Circle().fill((recorder.isArmed ? Color.red
                                           : PocketColor.textSecondary).opacity(0.15)))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(recorder.isArmed ? "Recording armed — turn off" : "Record this session")
        .accessibilityHint(recorder.isArmed ? "A take will record when you start training" : "")
    }
}

/// Pre-run guidance under Start: while armed, state *when* it records and nudge toward headphones on a
/// bleed route; if the mic was denied, point at Settings. Nothing when idle.
struct RecordSetupHint: View {
    var recorder: RecordingController

    var body: some View {
        if recorder.isArmed {
            // Always state *when* it records; fold the quality nudge into the same line on a bleed
            // route so it stays one hint, not two (device feedback 2026-07-17).
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
