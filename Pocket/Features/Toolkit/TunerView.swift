import SwiftUI

/// The **Tuner** screen (ADR 0115) — a free, live-mic tuner in the Toolkit. Drives `TunerEngine`
/// (the app's first live input tap) and shows the detected note, an arc-needle cents gauge, the
/// nearest string in standard tuning, and a **Hear** reference tone. It reports pitch; it never
/// grades playing (ADR 0070).
///
/// Slice 3 defaults to guitar standard tuning (guided by nearest string). Instrument / tuning /
/// chromatic mode / reference-pitch calibration arrive with the Tune Settings sheet in Slice 4.
///
/// **Mic hygiene:** the engine starts on appear (after permission) and stops on disappear *and* when
/// the scene leaves `.active`, so the mic is never held open in the background.
struct TunerView: View {
    @State private var engine = TunerEngine()
    @State private var permission = MicPermission.status
    @State private var hearTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    /// The tuning Slice 3 tunes against (guitar standard). Slice 4 makes this selectable.
    private let tuning = Instrument.guitar.standardTuning

    var body: some View {
        Group {
            if permission == .denied {
                deniedState
            } else {
                tuner
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Tuner")
        .navigationBarTitleDisplayMode(.inline)
        .tint(PocketColor.toolkit)
        .onAppear(perform: begin)
        .onDisappear {
            engine.stop()
            stopHear()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { begin() } else { engine.stop() }
        }
    }

    // MARK: - Tuner

    private var tuner: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)
            Text(statusText)
                .font(.futura(.title3, weight: .bold))
                .foregroundStyle(statusColor)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: statusText)
            noteCircle
            // On lock-on, drive the needle to dead centre to reinforce the in-tune state (it glides
            // there via the gauge's own animation), rather than hovering at the residual few cents.
            TunerGaugeView(cents: isConfirmed ? 0 : (reading?.cents ?? 0),
                           isInTune: isConfirmed || (reading?.isInTune ?? false),
                           isActive: reading != nil)
                .padding(.horizontal, 8)
            endLabels
            stringRow
            hearButton
            Spacer(minLength: 8)
            Text("A440 · Standard")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .textCase(.uppercase)
                .kerning(1.2)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .readableWidth()
        .onChange(of: engine.confirmationID) { _, _ in confirmFeedback() }
    }

    /// The big state-coloured note disc — green in tune, amber off, faint grey while listening — with a
    /// soft halo and a little "pop" the moment the note locks in (Fender-style at-a-glance state).
    private var noteCircle: some View {
        ZStack {
            Circle()
                .fill(PocketColor.active.opacity(0.16))
                .frame(width: 244, height: 244)
                .opacity(reading?.isInTune == true ? 1 : 0)
            Circle()
                .fill(circleColor)
                .frame(width: 200, height: 200)
            HStack(alignment: .top, spacing: 2) {
                Text(reading?.noteName ?? "—")
                    .font(.futura(size: 88, weight: .bold))
                    .foregroundStyle(circleTextColor)
                if let reading {
                    Text("\(reading.octave)")
                        .font(.futura(size: 26, weight: .medium))
                        .foregroundStyle(circleTextColor.opacity(0.65))
                        .padding(.top, 12)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: reading?.isInTune)
        .animation(.easeOut(duration: 0.15), value: reading?.midiNote)
        .scaleEffect(isConfirmed ? 1.04 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isConfirmed)
    }

    private var endLabels: some View {
        HStack {
            Text("♭ Flat")
            Spacer()
            Text("Sharp ♯")
        }
        .font(.futura(.caption, weight: .semibold))
        .foregroundStyle(PocketColor.textSecondary)
        .textCase(.uppercase)
        .kerning(0.8)
        .padding(.horizontal, 8)
    }

    private var stringRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(tuning.noteNames.enumerated()), id: \.offset) { index, name in
                let isTarget = reading != nil && index == nearestStringIndex
                Text(name)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(isTarget
                                     ? (reading?.isInTune == true ? PocketColor.active : PocketColor.toolkit)
                                     : PocketColor.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(isTarget ? PocketColor.surfaceStandard : .clear)
                    )
                    .overlay(
                        Circle().stroke(isTarget
                                        ? (reading?.isInTune == true ? PocketColor.active : PocketColor.toolkit)
                                        : PocketColor.surfaceBorder,
                                        lineWidth: 1.5)
                    )
            }
        }
        .animation(.easeOut(duration: 0.15), value: nearestStringIndex)
    }

    private var hearButton: some View {
        Button(action: toggleHear) {
            HStack(spacing: 8) {
                Image(systemName: hearTask != nil ? "stop.fill" : "speaker.wave.2.fill")
                Text(hearTask != nil ? "Stop" : "Hear \(targetLabel)")
            }
            .font(.futura(.subheadline, weight: .semibold))
            .foregroundStyle(PocketColor.toolkit)
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(Capsule().fill(PocketColor.toolkitCircleWash))
        }
        .buttonStyle(.plain)
        .disabled(reading == nil)
        .opacity(reading == nil ? 0.5 : 1)
        .accessibilityLabel(hearTask != nil ? "Stop reference tone" : "Hear reference tone")
    }

    // MARK: - Permission-denied

    private var deniedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 44))
                .foregroundStyle(PocketColor.textSecondary)
            Text("Microphone access is off")
                .font(.futura(.headline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text("The tuner listens through the mic. Turn it on in Settings to tune.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.futura(.subheadline, weight: .semibold))
            .foregroundStyle(PocketColor.toolkit)
            .padding(.top, 4)
        }
        .padding(32)
        .readableWidth()
    }

    // MARK: - Derived

    private var reading: TunerReading? { engine.reading }

    private var nearestStringIndex: Int {
        guard let reading else { return 0 }
        return tuning.nearestStringIndex(toMidi: reading.midiNote)
    }

    /// The open-note MIDI of the nearest string — what Hear sounds and what the label names.
    private var targetMIDI: Int? {
        reading == nil ? nil : tuning.midiNotes[nearestStringIndex]
    }

    private var targetLabel: String {
        guard let midi = targetMIDI else { return "" }
        let name = GuitarScale.noteName(forPitchClass: ((midi % 12) + 12) % 12)
        return "\(name)\(midi / 12 - 1)"
    }

    private var isConfirmed: Bool { engine.isConfirmed }

    /// Disc fill: green in tune, amber off, a faint neutral while listening.
    private var circleColor: Color {
        guard let reading else { return PocketColor.surfaceStandard }
        return reading.isInTune ? PocketColor.active : PocketColor.marker
    }

    /// Note letter colour: fixed near-black on the bright green/amber fills (accessible in both themes,
    /// where a token colour would flip and lose contrast); secondary grey on the faint idle disc.
    private var circleTextColor: Color {
        reading == nil ? PocketColor.textSecondary : Color.black
    }

    private var statusText: String {
        guard let reading else { return "Listening…" }
        if isConfirmed { return "You're in tune!" }
        if reading.isInTune { return "In tune" }
        return reading.cents < 0 ? "Too flat, tune up" : "Too sharp, tune down"
    }

    private var statusColor: Color {
        guard let reading else { return PocketColor.textSecondary }
        return reading.isInTune ? PocketColor.active : PocketColor.marker
    }

    // MARK: - Actions

    private func begin() {
        guard !isPreview else { return }
        switch MicPermission.status {
        case .granted:
            permission = .granted
            engine.start()
        case .undetermined:
            Task {
                let granted = await MicPermission.request()
                permission = MicPermission.status
                if granted { engine.start() }
            }
        case .denied:
            permission = .denied
        }
    }

    /// Fired once when a string locks in tune: a success haptic + a short, bright confirmation chime
    /// through the shared `ToneEngine` (which plays out over the tuner's record session without
    /// stealing it). The engine freezes detection for the chime's length so it can't feed back.
    private func confirmFeedback() {
        haptic(.success)
        ToneEngine.shared.sequence([84, 88], noteDuration: 0.12, gap: 0.02)   // C6→E6, a bright "ding"
    }

    private func toggleHear() {
        haptic(.light)
        if hearTask != nil { stopHear(); return }
        guard let midi = targetMIDI else { return }
        ToneEngine.shared.sound([midi], sustain: 1.8)
        hearTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            if !Task.isCancelled { hearTask = nil }
        }
    }

    private func stopHear() {
        hearTask?.cancel()
        hearTask = nil
        ToneEngine.shared.stop()
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#Preview("Tuner") {
    NavigationStack { TunerView() }
        .preferredColorScheme(.dark)
}
