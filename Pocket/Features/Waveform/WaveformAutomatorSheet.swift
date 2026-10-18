import SwiftUI

/// Set up and run a loop's **automator** — the speed ramp that steps playback from a start to a
/// target as the loop repeats (ADR 0013), up *or* down. Reached by the "A" control on a
/// loop row. The user sets where (start → target) and how granular (steps + loops-per-
/// step); the per-step % is derived. Speed-based; BPM equivalents show when the song's tempo is known.
///
/// **The ramp runs on this sheet** (ADR 0260 D3). *Set ramp* arms the loop and plays it from the top,
/// and the sheet stays up showing where the ramp has got to: the current plateau lit, the live speed,
/// the step and the pass. An exercise run lights its current plateau the same way. *Stop ramp*
/// disarms and pauses. A ramp that plays out disarms itself (`automatorAdvance`), and the sheet offers
/// *Run again*. **Leaving ends it**: Cancel, Close or a swipe always disarms, and also pauses if this
/// sheet started the run, so peeking at the sheet while the song plays leaves the song alone.
struct AutomatorSheet: View {
    let loop: Loop
    let song: Song
    /// Read, never driven: the pass count and the transport the running ramp is shown against.
    /// `PracticeAudioEngine` is `@Observable` and `loopIteration` changes once per wrap, so the hero
    /// follows the run without a timer or any state of its own.
    let engine: PracticeAudioEngine
    /// Arm and play from the top — `WaveformPracticeModel.startAutomator(for:)`.
    let onSet: () -> Void
    /// Disarm and pause — `WaveformPracticeModel.stopAutomator(for:)`.
    let onStop: () -> Void
    /// Carry on after something else paused the song mid-ramp: a call, or headphones coming out.
    let onResume: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var start: Double
    @State private var target: Double
    @State private var steps: Int
    @State private var loops: Int
    /// Whether the ramp on screen was started **here** and hasn't been stopped. It is what tells a run
    /// from a peek: a loop can arrive armed from before ADR 0260, and that ramp is not this sheet's.
    @State private var ranHere = false
    /// Whether any run has started in this presentation. Sticky, for the toolbar: once the loop has
    /// been set there is nothing left for *Cancel* to cancel, so it reads *Close*.
    @State private var hasRun = false

    init(loop: Loop, song: Song, engine: PracticeAudioEngine,
         onSet: @escaping () -> Void, onStop: @escaping () -> Void, onResume: @escaping () -> Void) {
        self.loop = loop
        self.song = song
        self.engine = engine
        self.onSet = onSet
        self.onStop = onStop
        self.onResume = onResume
        let config = loop.automator
        _start = State(initialValue: config.startSpeed)
        _target = State(initialValue: config.targetSpeed)
        _steps = State(initialValue: config.stepCount)
        _loops = State(initialValue: config.loopsPerStep)
    }

    /// Where the sheet stands (ADR 0260 D3).
    private enum Phase { case idle, running, paused, finished }

    private var phase: Phase {
        guard ranHere else { return .idle }
        // While the sheet is up only the ramp's own finish disarms it: Stop clears `ranHere` as well.
        guard loop.automatorEnabled else { return .finished }
        return engine.isPlaying ? .running : .paused
    }

    /// The fields lock while a ramp plays, so what is on screen is the ramp being played.
    private var isLive: Bool { phase == .running || phase == .paused }

    private var draft: AutomatorConfig {
        AutomatorConfig(startSpeed: start, targetSpeed: target, stepCount: steps,
                        loopsPerStep: loops, enabled: true)
    }
    /// The ramp's direction — drives both the staircase graphic and the BPM arrow.
    /// Equal start/target reads as **level** (flat on both sides), not ascending.
    private var shape: RampShape { RampShape.between(start, target) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                hero
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    percentField("Start", $start)
                    percentField("Target", $target)
                    intField("Steps", $steps, range: 1...20)
                    intField("Loops / step", $loops, range: 1...16)
                }
                if let bpm = song.bpm {
                    Text("\(TempoMath.effectiveBPM(songBPM: bpm, speed: start)) BPM"
                         + "  \(shape.arrow)  "
                         + "\(TempoMath.effectiveBPM(songBPM: bpm, speed: target)) BPM")
                        .font(.pocketMono(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Automator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(hasRun ? "Close" : "Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .presentationDetents([.large])
        // An edit after a finished ramp is a new ramp being set up, so *Done* gives way to *Set ramp*.
        .onChange(of: draft) { _, _ in if phase == .finished { ranHere = false } }
        .onDisappear(perform: leave)
    }

    // MARK: - Pieces

    private var hero: some View {
        VStack(spacing: 8) {
            // One bar per plateau (`steps + 1`), idle or running, so the shape doesn't jump on Set.
            RampStairs(shape: shape, steps: draft.plateauCount, currentStep: litPlateau)
            heroFigure
            Text(heroCaption)
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(panelBackground)
        .accessibilityElement(children: .combine)
    }

    /// Where the running ramp is, read off the engine's pass count against the **stored** ramp, the
    /// one `automatorAdvance` is playing.
    private var live: AutomatorProgress { loop.automator.progress(atLoopIteration: engine.loopIteration) }

    /// The plateau the staircase lights: the live one while the ramp plays, the target once it has
    /// played out, none while it is being set up.
    private var litPlateau: Int? {
        switch phase {
        case .idle: return nil
        case .running, .paused: return live.plateau
        case .finished: return draft.plateauCount - 1
        }
    }

    @ViewBuilder private var heroFigure: some View {
        switch phase {
        case .idle:
            figureText("\(percent(start))  →  \(percent(target))")
        case .running, .paused:
            let speed = loop.automator.speed(atLoopIteration: engine.loopIteration)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                figureText(percent(speed))
                if let bpm = song.bpm {
                    Text("\(TempoMath.effectiveBPM(songBPM: bpm, speed: speed)) BPM")
                        .font(.pocketMono(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        case .finished:
            figureText("Done · \(percent(target))")
        }
    }

    private func figureText(_ text: String) -> some View {
        Text(text)
            .font(.pocketMono(.title2).weight(.semibold))
            .foregroundStyle(PocketColor.textPrimary)
    }

    /// `Step k/N` counts plateaus 1-based, the metronome tracker's convention: the start is the first
    /// tempo you hold and the target the last.
    private var heroCaption: String {
        switch phase {
        case .idle, .finished:
            return "\(steps) step\(steps == 1 ? "" : "s")  ·  \(stepLabel)"
        case .running, .paused:
            let position = "Step \(live.plateau + 1)/\(draft.plateauCount)  ·  loop \(live.pass) of \(loops)"
            return phase == .paused ? position + "  ·  paused" : position
        }
    }

    @ViewBuilder private var bottomBar: some View {
        VStack(spacing: 10) {
            switch phase {
            case .idle: primaryButton("Set ramp", action: setRamp)
            case .finished: primaryButton("Run again", action: setRamp)
            case .running: stopButton
            case .paused:
                primaryButton("Resume", action: onResume)
                stopButton
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.futura(.headline)).frame(maxWidth: .infinity).padding(.vertical, 15)
        }
        .background(PocketColor.active, in: .rect(cornerRadius: 14))
        .foregroundStyle(.black)
    }

    private var stopButton: some View {
        Button(action: stopRamp) {
            Text("Stop ramp").font(.futura(.headline)).frame(maxWidth: .infinity).padding(.vertical, 15)
        }
        .background(PocketColor.danger, in: .rect(cornerRadius: 14))
        .foregroundStyle(.white)
    }

    private func percentField(_ label: String, _ value: Binding<Double>) -> some View {
        fieldPanel(label, valueText: percent(value.wrappedValue)) {
            Stepper(label, value: value, in: TempoMath.minSpeed...TempoMath.maxSpeed, step: 0.05)
                .labelsHidden()
        }
    }

    private func intField(_ label: String, _ value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        fieldPanel(label, valueText: "\(value.wrappedValue)") {
            Stepper(label, value: value, in: range).labelsHidden()
        }
    }

    private func fieldPanel<S: View>(_ label: String, valueText: String,
                                     @ViewBuilder stepper: () -> S) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.futura(.caption2, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            HStack {
                Text(valueText).font(.pocketMono(.title3)).foregroundStyle(PocketColor.textPrimary)
                Spacer()
                // Locked while a ramp plays, on the stepper itself and visibly. `.disabled` on the grid
                // above them left every + and − drawn as live on iOS 26: the lock has to be seen.
                stepper()
                    .disabled(isLive)
                    .opacity(isLive ? 0.4 : 1)
            }
        }
        .padding(12)
        .background(panelBackground)
    }

    // MARK: - Labels & actions

    private func percent(_ speed: Double) -> String { "\(Int((speed * 100).rounded()))%" }

    /// Signed derived per-step change, e.g. "+5% each" / "−4.3% each".
    private var stepLabel: String {
        let pct = draft.stepSize * 100
        guard abs(pct) >= 0.05 else { return "no change" }
        let rounded = (pct * 10).rounded() / 10
        let mag = abs(rounded)
        let num = mag == mag.rounded() ? "\(Int(mag))" : String(format: "%.1f", mag)
        return "\(rounded > 0 ? "+" : "−")\(num)% each"
    }

    private func setRamp() {
        var config = draft
        config.enabled = true
        loop.automator = config
        onSet()
        ranHere = true
        hasRun = true
    }

    private func stopRamp() {
        onStop()
        ranHere = false
    }

    /// Leaving ends the ramp (ADR 0260 D3), however the sheet went. A run started here is stopped
    /// outright — disarmed and paused, as *Stop ramp* would. Anything else is a peek, so the loop is
    /// disarmed and playback is left alone.
    private func leave() {
        if ranHere, loop.automatorEnabled {
            onStop()
        } else if loop.automatorEnabled {
            loop.automatorEnabled = false
        }
    }
}
