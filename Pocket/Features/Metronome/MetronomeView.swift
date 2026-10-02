import SwiftUI
import QuartzCore
#if canImport(UIKit)
import UIKit
#endif

/// The standalone metronome screen (ADR 0043, slice 3): play/stop, a tempo control
/// (steppers, slider, and reused tap-tempo), a named **time-signature** picker, the
/// Italian tempo marking, a **beat-flash indicator** that
/// reads the same generated grid as the audio so the two stay in step, and the free-play
/// **tempo automator** for ad-hoc ramps.
///
/// A pure **free-play tool** (ADR 0046): exercises and command-anchored training routines now
/// live in the top-level **Practice** space, not here. The automator's role is *discovery* —
/// ramp until your hands break down — and a later slice adds a "Save as exercise" seam that
/// hands a discovered tempo into Practice's create flow.
struct MetronomeView: View {
    @State private var engine: StandaloneMetronomeEngine
    /// Wall-clock times of recent taps for tap-tempo (`TempoMath.bpm(fromTapTimes:)`).
    @State private var taps: [TimeInterval] = []
    @Environment(\.dismiss) private var dismiss
    /// Whether the meter/withdrawal sheet is showing — everything that shapes how the bar is filled.
    @State private var showingSettings = false
    /// The note being composed, **carrying the snapshot taken when the pencil was tapped** (ADR 0160
    /// §5). Presenting it leaves the click running — the sheet touches no transport, which is the
    /// whole reason ADR 0142 built it, and the reason the tempo can move while it is open.
    ///
    /// Held in `@State` and presented by item rather than rebuilt in the sheet's content closure: that
    /// closure re-runs on every body pass, and this body reads `engine.bpm`, so a snapshot taken there
    /// would be whichever tempo the last re-render saw — neither the moment the player reached for the
    /// pencil nor the moment they saved.
    @State private var composing: PendingMetronomeNote?
    /// Whether the keyboard is up, for the tempo or an automator field. The pinned transport steps
    /// aside while it is: the field being typed into otherwise ends up squeezed against the Start
    /// button, half hidden, and the keyboard's checkmark floats over Start's trailing edge.
    @State private var keyboardUp = false
    @Environment(\.modelContext) private var modelContext
    /// When the click started, so that ending it can log the time as practice (ADR 0242). See
    /// `endSession()`.
    @State private var runLog = MetronomeRunLog()

    /// A tap gap longer than this starts a fresh measurement — an old, stale tap shouldn't
    /// average against a new one.
    private let tapResetGap: TimeInterval = 2.0

    /// `initialBPM` opens the screen already on a tempo the player arrived with — the song player's
    /// tempo-carry gateway (ADR 0170). `nil` (the Home hub's route, and every preview) keeps the
    /// free-play default.
    ///
    /// Seeded here, before the first body pass, rather than in `onAppear`: the readout, the marking
    /// and the slider all read `engine.bpm` while the body runs, so a later write would show 90 for
    /// a frame and then jump. Through `setBPM` rather than a seeding initialiser so the carried
    /// tempo meets the **same clamp** every other way in meets — a song at 1.5× can read past 300.
    /// Its two side effects are both `transport`-guarded and this engine is `.stopped`: there is no
    /// phase to re-anchor and nothing to publish to Now Playing.
    init(initialBPM: Int? = nil) {
        let engine = StandaloneMetronomeEngine()
        if let initialBPM { engine.setBPM(initialBPM) }
        _engine = State(initialValue: engine)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // `BeatIndicator` is an isolated struct so the engine's ~50 Hz `currentBeat`
                // updates re-render only it — not this body, which would otherwise rebuild the
                // controls (and dismiss the time-signature menu) on every beat.
                ScrollView {
                    VStack(spacing: 20) {
                        // The dots and the meter read as one thing: how the bar is counted, and the
                        // control that sets it.
                        VStack(spacing: 8) {
                            BeatIndicator(engine: engine)
                            meterChip
                        }
                        tempoReadout
                        tempoControls
                        MetronomeAutomatorPanel(engine: engine)
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
                // Transport stays pinned below the scrollable controls — except while typing.
                if !keyboardUp {
                    transport
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Back arrow + title + pencil — one control either side, so the title sits centred.
                // The meter used to be the second trailing control, and the pair was wide enough
                // that iOS moved the title off centre to fit it; it now sits under the beat dots.
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .tint(PocketColor.metronome)
                    .accessibilityLabel("Back")
                }
                ToolbarItem(placement: .principal) {
                    Text("Metronome")
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                // The second door onto the journal (ADR 0155 §8), now writing a **metronome** note
                // rather than a bare standalone one (ADR 0160). The sitting is snapshotted here, at
                // the tap, because that is the moment the player is reacting to. The button itself
                // is the one `ExerciseRunView` and `LoopRunView` use.
                ToolbarItem(placement: .topBarTrailing) {
                    QuickJournalButton { composing = PendingMetronomeNote(sitting: engine.journalContext) }
                }
            }
        }
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        // The free-play metronome is the **only** host that offers click withdrawal (ADR 0132 §4, as
        // amended): opt in explicitly, so no screen inherits it by sharing the engine type.
        .onAppear { engine.allowsClickWithdrawal = true }
        .onChange(of: engine.transport) { old, new in runLog.transportChanged(from: old, to: new) }
        .onDisappear(perform: endSession)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
        .sheet(isPresented: $showingSettings) {
            MetronomeSettingsSheet(engine: engine)
        }
        // ADR 0155 §8 refused a `.metronome` owner kind and any snapshot of the live BPM, on the
        // grounds that half a snapshot — a tempo with no unit attached to it — is false context.
        // **ADR 0160 reverses both**, conditionally: the objection was to a *fragment* of a unit's
        // context, and tempo + meter + subdivision + withdrawal on an entry that says it was written
        // at the click is a full description of a real thing, with nowhere wrong to attach it.
        .sheet(item: $composing) { pending in
            QuickJournalSheet(owner: .metronome(pending.sitting))
        }
    }

    // MARK: - Tempo readout

    /// The BPM number + marking, flanked by the − / + steppers (moved here so the slider row
    /// can hold the tap buttons instead of a separate full-width Tap row). The number itself is
    /// **typable** — see `TypableTempo`.
    private var tempoReadout: some View {
        HStack {
            tempoStepper(symbol: "minus", label: "Decrease tempo", delta: -1)
            Spacer()
            VStack(spacing: 2) {
                TypableTempo(engine: engine)
                // Free play is where the click withdrawal lands hardest (ADR 0132 §7a) — the eyes are
                // on the hands and the click is the only reference — so the caption carries its word
                // here too. Its own view, so the per-tick read doesn't rebuild these controls.
                RunTempoCaption(engine: engine, fallback: "BPM · \(engine.tempoMarking.name)",
                                tint: PocketColor.metronome)
            }
            Spacer()
            tempoStepper(symbol: "plus", label: "Increase tempo", delta: 1)
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
            tapButton(spoken: true)
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
            tapButton(spoken: false)
        }
    }

    /// One of the two **TAP** buttons flanking the slider.
    ///
    /// - Parameter spoken: whether VoiceOver meets this one. **Exactly one of the pair says yes**
    ///   (ADR 0213). The two exist so either thumb can reach one — an ergonomic reason that does not
    ///   survive into VoiceOver, where the pair is one action announced twice with nothing to choose
    ///   between them. The audit found it as two buttons sharing a label; the fix is not to invent a
    ///   second name for the same thing, it is to stop offering the duplicate.
    private func tapButton(spoken: Bool) -> some View {
        Button { recordTap() } label: {
            Text("TAP")
                .font(.futura(.caption, weight: .bold))
                .foregroundStyle(PocketColor.textPrimary)
                // `minWidth`, not `width` — the width twin of D6, and found the same way D6's row
                // was: by looking. At an accessibility text size a hard 56pt truncated the word to
                // a bare "…", so the two controls either side of the tempo slider became a pair of
                // unreadable ellipses. A fixed height clips a row; a fixed width eats the label.
                .frame(minWidth: 56, minHeight: 44)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(PocketColor.metronomeCardWash))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tap to set tempo")
        .accessibilityHidden(!spoken)
    }

    /// The tempo −/+ steppers: a single tap nudges ±1 BPM; holding auto-repeats and accelerates
    /// (shared `StepperButton`, V1 feedback #3 follow-up). `adjustBPM` clamps to `bpmRange`, so the
    /// step closure stays pure and `StepperButton` owns the hold-repeat haptics.
    private func tempoStepper(symbol: String, label: String, delta: Int) -> some View {
        StepperButton(symbol: symbol, label: label, tint: PocketColor.metronome,
                      fill: PocketColor.metronomeCircleWash, diameter: 44,
                      glyphFont: .futura(.title3, weight: .semibold)) {
            engine.adjustBPM(by: delta)
        }
    }

    // MARK: - Transport

    /// Primary play/pause/resume button, with a secondary **stop** (end + reset to 0:00)
    /// that appears once a session is live. Pause keeps the session; stop zeroes it.
    private var transport: some View {
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
            Button { engine.toggle(); haptic(.medium) } label: {
                Label(primaryLabel, systemImage: primarySymbol)
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.metronomeCTA))
            }
            .buttonStyle(.plain)
        }
    }

    /// Stop the click and log the time it sounded (ADR 0242). The two ways a sitting here ends — the
    /// Stop button and leaving the screen — both come through here.
    ///
    /// `elapsed` is read **before** `stop()`, which zeroes it. It is the engine's own session clock:
    /// kept across pauses, and advanced by the same tick that schedules the clicks, so while the click
    /// is sounding it is never more than a tick behind. Runs under 30 seconds are dropped by the
    /// writer — a tempo check, not practice.
    ///
    /// **Not on going to the background.** The click plays on through the lock screen by design, so
    /// backgrounding ends nothing. A sitting ended by closing the app from the app switcher is the one
    /// that goes unlogged: no seam runs.
    private func endSession() {
        let sounded = engine.elapsed
        engine.stop()
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

/// A composer that has been opened, holding the sitting as it stood at that instant (ADR 0160 §5).
///
/// The identity is the *presentation*, not the snapshot — a fresh `UUID` per tap — so `.sheet(item:)`
/// presents once and never re-presents itself when a value inside the snapshot happens to repeat. It
/// lives here rather than on `MetronomeJournalContext` so that type stays a pure, `Equatable` value
/// with no identity of its own to confuse a test.
private struct PendingMetronomeNote: Identifiable {
    let id = UUID()
    let sitting: MetronomeJournalContext
}

// MARK: - Meter (time signature + subdivision + click withdrawal)

extension MetronomeView {
    /// One control for everything that shapes **how the bar is filled** — time signature,
    /// subdivision, and click withdrawal. The label shows the compact signature plus the subdivision
    /// glyph in the accent colour when one is active ("4/4 ♫"). In a same-file extension so it doesn't
    /// bloat the main view body (SwiftLint type_body_length).
    ///
    /// **Under the beat dots, not in the nav bar.** It sat at the bar's trailing edge beside the
    /// journal pencil, and the pair was wider than the back button by enough that iOS could not centre
    /// the title between them and slid it left — on a 402pt phone it missed by about 2pt, on a 375pt
    /// one the two would have overlapped. Under the dots it also sits with the thing it changes: pick
    /// 3/4 and the row above it becomes three dots.
    ///
    /// It **opens a sheet, not a menu.** As a menu this had reached fifteen rows across three groups:
    /// it scrolled, so its first row was always clipped and you couldn't tell which group you were in;
    /// the longer signatures wrapped onto two lines; and click withdrawal, added last, sat at the
    /// bottom where you had to scroll blind to reach it. `MetronomeSettingsSheet` also has room for
    /// the footers — which is how click withdrawal got back the explanation it lost on the way out of
    /// Settings, and it is the one control here that can't do without one.
    var meterChip: some View {
        Button { showingSettings = true } label: {
            HStack(spacing: 6) {
                Text(engine.timeSignature.name)
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                if engine.subdivision != .none {
                    Text(engine.subdivision.glyph)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.metronome)
                }
                Image(systemName: "chevron.down")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Capsule().fill(PocketColor.metronomeCardWash))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Metronome settings. Time signature \(engine.timeSignature.name), "
                            + "subdivision \(engine.subdivision.label)")
    }
}

#Preview("Metronome") {
    MetronomeView()
}
