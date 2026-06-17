import SwiftUI

/// Set up a loop's **automator** — the speed ramp that steps playback from a start to a
/// target as the loop repeats (ADR 0013), up *or* down. Reached by the "A" control on a
/// loop row. The user sets where (start → target) and how granular (steps + loops-per-
/// step); the per-step % is derived. **Set ramp** arms it; **Turn off** disarms an armed
/// loop; **Cancel** discards. Speed-based; BPM equivalents show when the song's tempo is known.
struct AutomatorSheet: View {
    let loop: Loop
    let song: Song
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var start: Double
    @State private var target: Double
    @State private var steps: Int
    @State private var loops: Int
    private let wasEnabled: Bool

    init(loop: Loop, song: Song, onSave: @escaping () -> Void) {
        self.loop = loop
        self.song = song
        self.onSave = onSave
        let config = loop.automator
        _start = State(initialValue: config.startSpeed)
        _target = State(initialValue: config.targetSpeed)
        _steps = State(initialValue: config.stepCount)
        _loops = State(initialValue: config.loopsPerStep)
        wasEnabled = config.enabled
    }

    private var draft: AutomatorConfig {
        AutomatorConfig(startSpeed: start, targetSpeed: target, stepCount: steps,
                        loopsPerStep: loops, enabled: true)
    }
    private var ascending: Bool { target >= start }

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
                         + "  \(ascending ? "──►" : "◄──")  "
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .presentationDetents([.large])
    }

    // MARK: - Pieces

    private var hero: some View {
        VStack(spacing: 8) {
            RampStairs(ascending: ascending, steps: steps)
            Text("\(percent(start))  →  \(percent(target))")
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(PocketColor.textPrimary)
            Text("\(steps) step\(steps == 1 ? "" : "s")  ·  \(stepLabel)")
                .font(.footnote)
                .foregroundStyle(PocketColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(panelBackground)
    }

    private var bottomBar: some View {
        VStack(spacing: 6) {
            Button(action: setRamp) {
                Text("Set ramp").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
            }
            .background(PocketColor.active, in: .rect(cornerRadius: 14))
            .foregroundStyle(.black)
            if wasEnabled {
                Button("Turn off ramp", action: turnOff)
                    .font(.subheadline)
                    .foregroundStyle(PocketColor.textSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)
        .background(.ultraThinMaterial)
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
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PocketColor.textSecondary)
            HStack {
                Text(valueText).font(.title3.monospacedDigit()).foregroundStyle(PocketColor.textPrimary)
                Spacer()
                stepper()
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
        onSave()
        dismiss()
    }

    private func turnOff() {
        var config = draft
        config.enabled = false
        loop.automator = config
        onSave()
        dismiss()
    }
}

/// The hero climb: a row of bars rising (or falling) left→right to show the ramp shape.
private struct RampStairs: View {
    let ascending: Bool
    let steps: Int

    var body: some View {
        let barCount = min(max(steps, 2), 12)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<barCount, id: \.self) { index in
                let pos = Double(index) / Double(barCount - 1)   // 0→1 left→right
                let frac = ascending ? pos : 1 - pos             // flip for a descending ramp
                RoundedRectangle(cornerRadius: 2)
                    .fill(PocketColor.active.opacity(0.4 + 0.6 * frac))
                    .frame(width: 13, height: 14 + 44 * frac)
            }
        }
        .frame(height: 60, alignment: .bottom)
        .animation(.easeOut(duration: 0.2), value: ascending)
        .accessibilityHidden(true)
    }
}
