import SwiftUI

/// `LoopRunView`'s bottom transport — Start / pause / stop, the standalone-only record arm, and the
/// take status a routine block marked to record shows (ADR 0179). Twin of
/// `ExerciseRunView+Transport.swift`, split out for the same reason: the screen's struct body is at
/// the length cap CI enforces, and the transport is a clean seam.

extension LoopRunView {
    var transport: some View {
        VStack(spacing: 10) {
            // See the twin comment in `ExerciseRunView` — a readout, not a control (ADR 0179).
            if routineContext?.recordsTake == true { RecordingStatusView(recorder: recorder) }
            transportControls
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(PocketColor.background.opacity(0.95))
    }

    var transportControls: some View {
        HStack(spacing: 14) {
            if isRunning {
                Button { model.stop(); haptic(.medium) } label: {
                    Image(systemName: "stop.fill")
                        .font(.futura(.title3))
                        .foregroundStyle(PocketColor.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(PocketColor.textSecondary.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and reset")
                Button { model.toggle(); haptic(.medium) } label: {
                    Label(model.transport == .playing ? "Pause" : "Resume",
                          systemImage: model.transport == .playing ? "pause.fill" : "play.fill")
                        .pocketRunButton
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    if model.loadFailed {
                        Text("Couldn't load this song's audio — the file may have moved or been deleted.")
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    HStack(spacing: 14) {
                        Button(action: startTapped) {
                            Label("Start training", systemImage: "play.fill").pocketRunButton
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isLoading || model.loadFailed)
                        .accessibilityLabel("Start training routine")
                        // Recording is a standalone-practice feature — routine blocks stay focused
                        // (ADR 0071/0077), matching the Takes/Journal bar's `routineContext == nil` gate.
                        if routineContext == nil {
                            RecordArmToggle(recorder: recorder,
                                            disabled: model.isLoading || model.loadFailed)
                        }
                    }
                    RecordSetupHint(recorder: recorder)
                }
                .animation(.easeInOut(duration: 0.2), value: recorder.isArmed)
            }
        }
    }
}
