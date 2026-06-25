import SwiftUI
import QuartzCore

/// The standalone metronome screen (ADR 0043, slice 3): play/stop, a tempo control
/// (steppers, slider, and reused tap-tempo), a time-signature control, the Italian tempo
/// marking, a running **session tracker**, and a **beat-flash indicator** that reads the
/// same generated grid as the audio so the two can't drift.
///
/// No persistence yet — the tempo/signature are in-memory for the sitting. Savable
/// exercise presets (loading a preset's full configuration) arrive in slice 6.
struct MetronomeView: View {
    @State private var engine = StandaloneMetronomeEngine()
    /// Wall-clock times of recent taps for tap-tempo (`TempoMath.bpm(fromTapTimes:)`).
    @State private var taps: [TimeInterval] = []
    @Environment(\.dismiss) private var dismiss

    /// A tap gap longer than this starts a fresh measurement — an old, stale tap shouldn't
    /// average against a new one.
    private let tapResetGap: TimeInterval = 2.0

    /// The tempo slider's bounds as `Double`, from the engine's integer `bpmRange`.
    private var bpmSliderRange: ClosedRange<Double> {
        Double(StandaloneMetronomeEngine.bpmRange.lowerBound)
            ... Double(StandaloneMetronomeEngine.bpmRange.upperBound)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                beatIndicator
                tempoReadout
                tempoControls
                timeSignatureControl
                Spacer(minLength: 0)
                transport
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Metronome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(PocketColor.metronome)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { engine.stop() }
    }

    // MARK: - Beat indicator

    /// A dot per beat in the bar; the current beat lights up and the downbeat (beat 1)
    /// reads in the metronome accent colour and a touch larger. Driven by the engine's
    /// `currentBeat`, the same grid the audio sounds (ADR 0043).
    private var beatIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<engine.beatsPerBar, id: \.self) { index in
                let isCurrent = engine.isPlaying && engine.currentBeat % engine.beatsPerBar == index
                let isDownbeat = index == 0
                Circle()
                    .fill(dotColor(isCurrent: isCurrent, isDownbeat: isDownbeat))
                    .frame(width: isDownbeat ? 20 : 16, height: isDownbeat ? 20 : 16)
                    .scaleEffect(isCurrent ? 1.35 : 1.0)
                    .animation(.easeOut(duration: 0.08), value: engine.currentBeat)
            }
        }
        .frame(height: 32)
        .accessibilityHidden(true)
    }

    private func dotColor(isCurrent: Bool, isDownbeat: Bool) -> Color {
        if isCurrent { return isDownbeat ? PocketColor.metronome : PocketColor.textPrimary }
        return isDownbeat ? PocketColor.metronome.opacity(0.4) : PocketColor.textSecondary.opacity(0.4)
    }

    // MARK: - Tempo readout

    private var tempoReadout: some View {
        VStack(spacing: 2) {
            Text("\(engine.bpm)")
                .font(.pocketMono(.largeTitle))
                .foregroundStyle(PocketColor.textPrimary)
                .contentTransition(.numericText())
            Text("BPM · \(engine.tempoMarking.name)")
                .font(.caption)
                .foregroundStyle(PocketColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(engine.bpm) beats per minute, \(engine.tempoMarking.name)")
    }

    // MARK: - Tempo controls

    private var tempoControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                stepperButton(symbol: "minus", delta: -1)
                Slider(
                    value: Binding(
                        get: { Double(engine.bpm) },
                        set: { engine.setBPM(Int($0.rounded())) }
                    ),
                    in: bpmSliderRange
                )
                .tint(PocketColor.metronome)
                .accessibilityLabel("Tempo")
                stepperButton(symbol: "plus", delta: 1)
            }
            Button { recordTap() } label: {
                Label("Tap tempo", systemImage: "hand.tap")
                    .font(.subheadline)
                    .foregroundStyle(PocketColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(PocketColor.metronome.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tap to set tempo")
        }
    }

    private func stepperButton(symbol: String, delta: Int) -> some View {
        Button { engine.adjustBPM(by: delta); haptic(.light) } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(PocketColor.metronome.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? "Increase tempo" : "Decrease tempo")
    }

    // MARK: - Time signature

    private var timeSignatureControl: some View {
        HStack {
            Text("Beats per bar")
                .font(.subheadline)
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            Stepper(
                value: Binding(
                    get: { engine.beatsPerBar },
                    set: { engine.setBeatsPerBar($0) }
                ),
                in: StandaloneMetronomeEngine.beatsPerBarRange
            ) {
                Text("\(engine.beatsPerBar)")
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            .fixedSize()
        }
    }

    // MARK: - Transport

    private var transport: some View {
        VStack(spacing: 12) {
            Text(timecode(engine.elapsed))
                .font(.pocketMono(.title3))
                .foregroundStyle(engine.isPlaying ? PocketColor.textPrimary : PocketColor.textSecondary)
                .contentTransition(.numericText())
                .accessibilityLabel("Session time \(timecode(engine.elapsed))")

            Button { engine.toggle(); haptic(.medium) } label: {
                Label(engine.isPlaying ? "Stop" : "Start",
                      systemImage: engine.isPlaying ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .foregroundStyle(PocketColor.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.metronome))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tap tempo (reuses TempoMath, ADR 0024 / 0043)

    private func recordTap() {
        let now = CACurrentMediaTime()
        if let last = taps.last, now - last > tapResetGap { taps.removeAll() }
        taps.append(now)
        haptic(.light)
        if let bpm = TempoMath.bpm(fromTapTimes: taps) {
            engine.setBPM(Int(bpm.rounded()))
        }
    }
}

#Preview("Metronome") {
    MetronomeView()
}
