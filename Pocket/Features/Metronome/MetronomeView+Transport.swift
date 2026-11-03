import SwiftUI

/// `MetronomeView`'s pinned transport — Start / Pause / Resume, a secondary Stop once a session is
/// live, and, while stopped, the take arm beside Start (ADR 0287).
///
/// Its own file, as `ExerciseRunView+Transport` is: `MetronomeView.swift` was at the 400-line cap, and
/// the transport is a clean seam.
extension MetronomeView {

    /// Primary play/pause/resume button, with a secondary **stop** (end + reset to 0:00)
    /// that appears once a session is live. Pause keeps the session; stop zeroes it.
    ///
    /// The arm shows **only while stopped**, as on an exercise run: a take begins with the click, and
    /// arming mid-click would flip the audio session under it (ADR 0287 D2). While a take rolls, the
    /// red dot and timer above the buttons say so.
    var transport: some View {
        VStack(spacing: 10) {
            RecordingStatusView(recorder: recorder,
                                bleedNudge: "The click is in the take. Headphones record just your playing.")
            HStack(spacing: 14) {
                if engine.transport != .stopped {
                    Button { endSession(); haptic(.medium) } label: {
                        Image(systemName: "stop.fill")
                            .font(.futura(.title3))
                            .foregroundStyle(PocketColor.textPrimary)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(PocketColor.textSecondary.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop and reset")
                }
                Button { primaryTapped(); haptic(.medium) } label: {
                    Label(primaryLabel, systemImage: primarySymbol)
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.metronomeCTA))
                }
                .buttonStyle(.plain)
                if engine.transport == .stopped {
                    RecordArmToggle(recorder: recorder,
                                    armedHint: "A take will record when you start the click")
                }
            }
            if engine.transport == .stopped {
                RecordSetupHint(recorder: recorder, startPhrase: "when the click starts",
                                bleedNote: "the click will be in the take")
                MetronomeTakesLine(recorder: recorder) { showingTakes = true }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: recorder.isArmed)
    }

    /// Stopped → start the click, through `startClick` so an armed take begins first. Otherwise the
    /// engine's own pause / resume.
    private func primaryTapped() {
        if engine.transport == .stopped {
            startClick(engine.start)
        } else {
            engine.toggle()
        }
    }

    /// Stop the click and log the time it sounded (ADR 0242). The two ways a sitting here ends — the
    /// Stop button and leaving the screen — both come through here, and both end a rolling take.
    ///
    /// `elapsed` is read **before** `stop()`, which zeroes it. It is the engine's own session clock:
    /// kept across pauses, and advanced by the same tick that schedules the clicks, so while the click
    /// is sounding it is never more than a tick behind. Runs under 30 seconds are dropped by the
    /// writer — a tempo check, not practice.
    ///
    /// The click stops **before** the take ends, so the session's flip back to playback happens with
    /// nothing sounding.
    ///
    /// **Not on going to the background.** The click plays on through the lock screen by design, so
    /// backgrounding ends nothing but a take (`endsTakeOnLeavingApp`). A sitting ended by closing the
    /// app from the app switcher is the one that goes unlogged: no seam runs.
    func endSession() {
        let sounded = engine.elapsed
        engine.stop()
        finishTake()
        guard let run = runLog.finish(soundedSeconds: sounded) else { return }
        PracticeLogWriter.log(kind: .metronome, startedAt: run.start, endedAt: run.end,
                              unitUID: nil, into: modelContext)
    }

    private var primaryLabel: String {
        switch engine.transport {
        case .stopped: return "Start"
        case .playing: return "Pause"
        case .paused: return "Resume"
        }
    }

    private var primarySymbol: String {
        engine.transport == .playing ? "pause.fill" : "play.fill"
    }
}
