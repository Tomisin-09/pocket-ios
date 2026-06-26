import SwiftUI
import QuartzCore
#if canImport(UIKit)
import UIKit
#endif

/// The standalone metronome screen (ADR 0043, slice 3): play/stop, a tempo control
/// (steppers, slider, and reused tap-tempo), a named **time-signature** picker, the
/// Italian tempo marking, a running **session tracker**, and a **beat-flash indicator**
/// that reads the same generated grid as the audio so the two stay in step.
///
/// Configurations are savable as **exercise presets** (ADR 0043, slice 6) via the presets
/// button; loading one applies its full configuration and titles the screen with its name.
struct MetronomeView: View {
    @State private var engine = StandaloneMetronomeEngine()
    /// Wall-clock times of recent taps for tap-tempo (`TempoMath.bpm(fromTapTimes:)`).
    @State private var taps: [TimeInterval] = []
    /// The loaded exercise preset, if any — its name titles the screen.
    @State private var loadedExercise: MetronomeExercise?
    @State private var showingLibrary = false
    /// Long-pressing the (possibly truncated) title pops the full name in a popover.
    @State private var showingFullTitle = false
    @Environment(\.dismiss) private var dismiss

    /// A tap gap longer than this starts a fresh measurement — an old, stale tap shouldn't
    /// average against a new one.
    private let tapResetGap: TimeInterval = 2.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // The two per-tick views are isolated structs so the engine's ~50 Hz
                // `currentBeat`/`elapsed` updates re-render only them — not this body, which
                // would otherwise rebuild the controls (and dismiss the time-signature menu)
                // on every beat.
                ScrollView {
                    VStack(spacing: 20) {
                        if let exercise = loadedExercise {
                            // Loaded-exercise progress (current→target + manual nudge), slice 7.
                            // Slim chip directly under the header so it doesn't crowd the dots.
                            ExerciseProgressChip(exercise: exercise)
                        }
                        BeatIndicator(engine: engine)
                        tempoReadout
                        tempoControls
                        MetronomeAutomatorPanel(engine: engine)
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
                // Session readout + transport stay pinned below the scrollable controls.
                VStack(spacing: 12) {
                    // Session timer stays centred behind the action row: loaded-exercise
                    // actions on the leading edge, save-new + library on the trailing edge,
                    // all kept off the nav bar so they don't truncate the title.
                    ZStack {
                        SessionTracker(engine: engine)
                        ExerciseActionBar(engine: engine, loadedExercise: $loadedExercise,
                                          showLibrary: { showingLibrary = true })
                    }
                    transport
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Back arrow + title + meter, so the screen reads as a feature you navigate
                // into, not a settings sheet. The meter (time signature + subdivision) moves
                // to the trailing edge.
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .tint(PocketColor.metronome)
                    .accessibilityLabel("Back")
                }
                ToolbarItem(placement: .principal) {
                    titleLabel
                }
                ToolbarItem(placement: .topBarTrailing) {
                    meterMenu
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .tint(PocketColor.metronome)
                }
            }
            .sheet(isPresented: $showingLibrary) {
                MetronomeLibrarySheet(engine: engine, loadedExercise: $loadedExercise)
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { engine.stop() }
    }

    // MARK: - Tempo readout

    /// The BPM number + marking, flanked by the − / + steppers (moved here so the slider row
    /// can hold the tap buttons instead of a separate full-width Tap row).
    private var tempoReadout: some View {
        HStack {
            stepperButton(symbol: "minus", delta: -1)
            Spacer()
            VStack(spacing: 2) {
                Text("\(engine.bpm)")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                Text("BPM · \(engine.tempoMarking.name)")
                    .font(.caption)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer()
            stepperButton(symbol: "plus", delta: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(engine.bpm) beats per minute, \(engine.tempoMarking.name)")
    }

    // MARK: - Tempo controls

    /// The slider flanked by a **TAP** button on each side — tap to the beat with either
    /// thumb. The steppers live with the readout above. The slider rides a **perceptual
    /// (log) scale** (`TempoSliderScale`) so its midpoint is ~95 BPM and typical 60–120
    /// tempos fill the centre, rather than the linear midpoint of ~165 making 90 BPM look slow.
    private var tempoControls: some View {
        HStack(spacing: 12) {
            tapButton
            Slider(
                value: Binding(
                    get: {
                        TempoSliderScale.position(forBPM: engine.bpm,
                                                  in: StandaloneMetronomeEngine.bpmRange)
                    },
                    set: {
                        engine.setBPM(TempoSliderScale.bpm(forPosition: $0,
                                                           in: StandaloneMetronomeEngine.bpmRange))
                    }
                ),
                in: 0...1
            )
            .tint(PocketColor.metronome)
            .accessibilityLabel("Tempo")
            tapButton
        }
    }

    private var tapButton: some View {
        Button { recordTap() } label: {
            Text("TAP")
                .font(.caption.weight(.bold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 56, height: 44)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(PocketColor.metronome.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tap to set tempo")
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

    // MARK: - Meter controls

    // MARK: - Title

    private var navTitle: String { loadedExercise?.name ?? "Metronome" }

    /// The screen title, which truncates when an exercise name is long and the meter + back
    /// arrow crowd the bar. Long-press to pop the full name in a small popover.
    private var titleLabel: some View {
        Text(navTitle)
            .font(.headline)
            .foregroundStyle(PocketColor.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .onLongPressGesture {
                guard loadedExercise != nil else { return }
                showingFullTitle = true
            }
            .popover(isPresented: $showingFullTitle) {
                Text(navTitle)
                    .font(.headline)
                    .foregroundStyle(PocketColor.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Meter (time signature + subdivision)

    /// One nav-bar menu for both the **time signature** and the **subdivision** — they shape
    /// the same thing (how the bar and beat are filled), so folding the subdivision into the
    /// meter menu reclaims a whole content row. The label shows the compact signature, plus
    /// the subdivision glyph in the accent colour when one is active ("4/4 ♫").
    private var meterMenu: some View {
        Menu {
            Section("Time signature") {
                ForEach(TimeSignature.presets) { signature in
                    Button {
                        engine.setTimeSignature(signature)
                        haptic(.light)
                    } label: {
                        if signature == engine.timeSignature {
                            Label("\(signature.name) · \(signature.context)", systemImage: "checkmark")
                        } else {
                            Text("\(signature.name) · \(signature.context)")
                        }
                    }
                }
            }
            Section("Subdivision") {
                ForEach(Subdivision.pickerOrder) { value in
                    Button {
                        engine.setSubdivision(value)
                        haptic(.light)
                    } label: {
                        if value == engine.subdivision {
                            Label(value.label, systemImage: "checkmark")
                        } else {
                            Text(value.label)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(engine.timeSignature.name)
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                if engine.subdivision != .none {
                    Text(engine.subdivision.glyph)
                        .font(.body)
                        .foregroundStyle(PocketColor.metronome)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .accessibilityLabel("Time signature \(engine.timeSignature.name), "
                            + "subdivision \(engine.subdivision.label)")
    }

    // MARK: - Transport

    /// Primary play/pause/resume button, with a secondary **stop** (end + reset to 0:00)
    /// that appears once a session is live. Pause keeps the session; stop zeroes it.
    private var transport: some View {
        HStack(spacing: 14) {
            if engine.transport != .stopped {
                Button { engine.stop(); haptic(.medium) } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundStyle(PocketColor.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(PocketColor.textSecondary.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and reset")
            }
            Button { engine.toggle(); haptic(.medium) } label: {
                Label(primaryLabel, systemImage: primarySymbol)
                    .font(.headline)
                    .foregroundStyle(PocketColor.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.metronome))
            }
            .buttonStyle(.plain)
        }
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

    /// Dismiss the number-pad keyboard from the screen-level **Done** accessory. Resigning
    /// first responder flips each field's focus, which commits its typed value.
    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }
}

/// A dot per click in the bar; the current click lights up and the meter's **accented**
/// clicks read in the metronome colour and a touch larger. A standalone view so the
/// engine's per-tick `currentBeat` updates re-render only the dots, not the whole screen
/// (which would dismiss the time-signature menu mid-play).
private struct BeatIndicator: View {
    let engine: StandaloneMetronomeEngine

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<engine.timeSignature.beats, id: \.self) { index in
                let isCurrent = engine.isPlaying
                    && engine.currentBeat % engine.timeSignature.beats == index
                let isAccent = engine.timeSignature.isAccented(beatInBar: index)
                Circle()
                    .fill(dotColor(isCurrent: isCurrent, isAccent: isAccent))
                    .frame(width: isAccent ? 18 : 14, height: isAccent ? 18 : 14)
                    .scaleEffect(isCurrent ? 1.4 : 1.0)
                    .animation(.easeOut(duration: 0.07), value: engine.currentBeat)
            }
        }
        .frame(height: 32)
        .accessibilityHidden(true)
    }

    private func dotColor(isCurrent: Bool, isAccent: Bool) -> Color {
        if isCurrent { return isAccent ? PocketColor.metronome : PocketColor.textPrimary }
        return isAccent ? PocketColor.metronome.opacity(0.4) : PocketColor.textSecondary.opacity(0.4)
    }
}

/// The running session time — ephemeral wall-clock that keeps running through tempo
/// changes and resets on stop (ADR 0043). A standalone view so its per-second update
/// doesn't re-render the controls.
private struct SessionTracker: View {
    let engine: StandaloneMetronomeEngine

    var body: some View {
        VStack(spacing: 2) {
            Text("SESSION")
                .font(.caption2.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(PocketColor.textSecondary)
            Text(timecode(engine.elapsed))
                .font(.pocketMono(.title))
                .foregroundStyle(engine.transport == .stopped
                                 ? PocketColor.textSecondary : PocketColor.textPrimary)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session time \(timecode(engine.elapsed))")
    }
}

#Preview("Metronome") {
    MetronomeView()
}
