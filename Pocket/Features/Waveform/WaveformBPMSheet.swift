import SwiftUI

/// Set an unknown (or wrong) tempo — rung 3 of ADR 0004's fallback chain, behind the
/// "Set BPM" affordance (ADR 0024). Two ways in:
///
/// - **Tap**: play the song and tap along; each tap captures the live **song-time**
///   (`PracticeAudioEngine.currentTime`), so tapping inside a loop or at a reduced
///   speed still reads the song's true tempo. "Mark the 1" stamps the bar-1 downbeat
///   (the phase anchor the beat grid needs — ADR 0022).
/// - **Manual**: type the BPM, optionally stamping the 1 at the current playhead.
///
/// The sheet computes a full-precision BPM (`TempoMath.bpm(fromTapTimes:)`) and hands
/// it back via `onCommit`; the model stores it in `Song.preciseBPM` (grid) and mirrors
/// the rounded value into `Song.bpm` (display). Reads the engine's observable state
/// live so the play/pause label and tap capture stay in sync.
struct BPMSheet: View {
    /// The live engine — read for `currentTime` (tap capture) and `isPlaying`, and
    /// driven for play/pause so the user can audition while tapping.
    let engine: PracticeAudioEngine
    /// The song's current precise/rounded tempo, to prefill Manual mode.
    let currentBPM: Double?
    /// `(bpm, downbeatSeconds)` — either may be `nil`; the model sets only what's given.
    let onCommit: (Double?, TimeInterval?) -> Void
    /// "Set the 1 on the waveform" — commits the current BPM (if any) and hands off to
    /// the on-waveform downbeat handle. The sheet dismisses first.
    let onSetOnWaveform: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable, Identifiable {
        case tap = "Tap"
        case manual = "Manual"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .tap
    /// Tap-mode capture: song-time of each tap (see `TempoMath.bpm(fromTapTimes:)`).
    @State private var taps: [TimeInterval] = []
    /// Manual-mode BPM text.
    @State private var manualText: String
    /// The bar-1 downbeat ("the 1"), shared by both modes. `nil` ⇒ leave phase as-is.
    @State private var downbeat: TimeInterval?

    init(engine: PracticeAudioEngine, currentBPM: Double?,
         onCommit: @escaping (Double?, TimeInterval?) -> Void,
         onSetOnWaveform: @escaping (Double?) -> Void) {
        self.engine = engine
        self.currentBPM = currentBPM
        self.onCommit = onCommit
        self.onSetOnWaveform = onSetOnWaveform
        _manualText = State(initialValue: currentBPM.map { String(Int($0.rounded())) } ?? "")
    }

    /// The BPM the current mode would commit (full precision), or `nil` if not set.
    private var resolvedBPM: Double? {
        switch mode {
        case .tap:
            return TempoMath.bpm(fromTapTimes: taps)
        case .manual:
            guard let value = Double(manualText.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
            return value.clamped(to: TempoMath.minTapBPM...TempoMath.maxTapBPM)
        }
    }

    private var canCommit: Bool { resolvedBPM != nil || downbeat != nil }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if mode == .tap { tapSection } else { manualSection }

                downbeatSection
            }
            .navigationTitle("Set tempo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onCommit(resolvedBPM, downbeat)
                        dismiss()
                    }
                    .disabled(!canCommit)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Tap mode

    private var tapSection: some View {
        Section {
            VStack(spacing: 14) {
                bpmReadout(resolvedBPM)

                Button { recordTap() } label: {
                    Text("Tap")
                        .font(.pocketMono(.title2))
                        .foregroundStyle(PocketColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                        .background(RoundedRectangle(cornerRadius: 16)
                            .fill(PocketColor.active.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(PocketColor.active.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tap to the beat")

                HStack {
                    Button { engine.togglePlay() } label: {
                        Label(engine.isPlaying ? "Pause" : "Play",
                              systemImage: engine.isPlaying ? "pause.fill" : "play.fill")
                    }
                    Spacer()
                    Button("Reset") { taps.removeAll() }
                        .foregroundStyle(PocketColor.textSecondary)
                        .disabled(taps.isEmpty)
                }
                .font(.subheadline)
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Play the song and tap along to the beat. Tapping reads the playhead, "
                 + "so a loop or slowed-down speed still reads the true tempo.")
        }
    }

    // MARK: Manual mode

    private var manualSection: some View {
        Section("Tempo") {
            HStack {
                TextField("BPM", text: $manualText)
                    .keyboardType(.decimalPad)
                    .font(.pocketMono(.body))
                Text("BPM")
                    .font(.caption)
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    // MARK: Shared downbeat ("the 1")

    private var downbeatSection: some View {
        Section {
            Button { downbeat = engine.currentTime } label: {
                Label("Mark the 1 at the playhead", systemImage: "1.circle")
            }
            Button {
                let bpm = resolvedBPM
                dismiss()
                onSetOnWaveform(bpm)
            } label: {
                Label("Set the 1 on the waveform", systemImage: "waveform.path")
            }
            if let downbeat {
                LabeledContent("Downbeat") {
                    HStack(spacing: 8) {
                        Text(timecode(downbeat)).font(.pocketMono(.body))
                        Button { self.downbeat = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear downbeat")
                    }
                }
            } else {
                Label("Not set — the tempo shows, but no beat grid is drawn",
                      systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
            }
        } header: {
            Text("The 1 (downbeat)")
        } footer: {
            Text("The 1 is where a bar starts — it anchors the beat grid's phase. Mark it "
                 + "at the playhead, or drag it onto a snare/kick peak on the waveform.")
        }
    }

    private func bpmReadout(_ bpm: Double?) -> some View {
        VStack(spacing: 0) {
            Text(bpm.map { String(Int($0.rounded())) } ?? "—")
                .font(.pocketMono(.largeTitle))
                .foregroundStyle(PocketColor.textPrimary)
                .contentTransition(.numericText())
            Text("BPM")
                .font(.caption2)
                .foregroundStyle(PocketColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bpm.map { "\(Int($0.rounded())) beats per minute" } ?? "Tempo not set")
    }

    private func recordTap() {
        taps.append(engine.currentTime)
        haptic(.light)
    }
}
