import SwiftUI

/// `ExerciseRunView`'s bottom transport — Start / pause / stop, the standalone-only record arm, and
/// the take status a routine block marked to record shows (ADR 0179).
///
/// Its own file rather than a same-file extension: `ExerciseRunView.swift` is at the 400-line cap CI
/// enforces, and the transport is a clean seam — nothing else in the screen touches it.

extension ExerciseRunView {
    var transport: some View {
        VStack(spacing: 10) {
            // A readout, never a control (ADR 0179): a marked block's take was armed on appearance,
            // so there is nothing here to tap — the red dot and running timer only say that it is
            // happening. `RecordingStatusView` draws nothing when not recording, so an unmarked
            // block's transport is unchanged.
            if routineContext?.recordsTake == true { RecordingStatusView(recorder: recorder) }
            transportControls
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(PocketColor.background.opacity(0.95))
    }

    /// Stopped → **Start training** (commit + `run(ramp:)`). Running → pause / resume with a
    /// secondary stop that ends the run and clears the ramp.
    var transportControls: some View {
        HStack(spacing: 14) {
            if isRunning {
                Button { engine.stop(); haptic(.medium) } label: {
                    Image(systemName: "stop.fill")
                        .font(.futura(.title3))
                        .foregroundStyle(PocketColor.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(PocketColor.textSecondary.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and reset")
                Button { engine.toggle(); haptic(.medium) } label: {
                    Label(engine.transport == .playing ? "Pause" : "Resume",
                          systemImage: engine.transport == .playing ? "pause.fill" : "play.fill")
                        .pocketRunButton
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 14) {
                        Button(action: commitAndStart) {
                            Label("Start training", systemImage: "play.fill").pocketRunButton
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start training routine")
                        // Standalone-only — routine blocks stay focused (ADR 0071/0077), matching the
                        // Takes/Journal bar gate.
                        if routineContext == nil {
                            RecordArmToggle(recorder: recorder)
                        }
                    }
                    RecordSetupHint(recorder: recorder)
                }
                .animation(.easeInOut(duration: 0.2), value: recorder.isArmed)
            }
        }
    }
}
