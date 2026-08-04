import SwiftData
import SwiftUI

/// What a tapped routine block previews — an exercise or a loop, resolved into the app context,
/// together with **the block itself**. Identifiable so `RoutineDetailView` can drive a
/// `navigationDestination(item:)` push.
///
/// The block rides along because the preview is where its *length* is both stated and decided: a
/// generated block's ramp is fitted to its allotted minutes at run time (ADR 0129 as amended) —
/// without them the preview drew the *authored* staircase while the run played the *fitted* one — and
/// ADR 0130 puts the opt-out from that fit on this same screen, next to the numbers it changes. The
/// unit is resolved into the app context; the block stays the editor's, which is the context that
/// owns writing it back.
enum RoutineBlockPreviewTarget: Identifiable, Hashable {
    case exercise(Exercise, block: RoutineItem)
    case loop(Loop, block: RoutineItem)
    /// A loop block in one of its **ramp-less** modes — ear training (ADR 0104) or improvise (ADR
    /// 0135). No staircase to fit and none to decline, but since ADR 0141 it does carry a length, so
    /// it travels with its block like the other two.
    case rampLess(Loop, mode: LoopRunMode, block: RoutineItem)
    /// A **freeform** exercise block (ADR 0136). Ramp-less for the same reason as the case above, but
    /// an exercise rather than a loop — and the only preview that is *editable*, because a freeform
    /// block's content is the text you'd want to change while looking at it.
    case freeform(Exercise, block: RoutineItem)

    var id: PersistentIdentifier {
        switch self {
        case .exercise(let exercise, _), .freeform(let exercise, _): return exercise.persistentModelID
        case .loop(let loop, _), .rampLess(let loop, _, _): return loop.persistentModelID
        }
    }
}

/// A **read-only, pre-start preview** of an exercise block (ADR 0071 R4b): shows *what* you'll play
/// (the template content rendered) and *how* (the tempo anchors + the staircase), plus a short
/// command-tempo **audio preview** — so you understand every block from the routine before you start,
/// removing the need for previews mid-session. It is deliberately read-only (no engine, no promote,
/// no Start): it reads the exercise's stored values and composes the same standalone content cards the
/// run screen uses. Deeper tuning stays behind the **Details** button (`ExerciseDetailSheet`).
struct ExerciseBlockPreview: View {
    let exercise: Exercise
    /// Minutes a generated session allotted this block, or `nil` when hand-authored (ADR 0129) — the
    /// staircase and dwell caption below describe the ramp fitted to it, which is the one the run
    /// will play.
    var plannedMinutes: Int?
    /// The block's opt-out from that fit (ADR 0130). Bound to the `RoutineItem`, so toggling it
    /// re-draws the staircase here and re-flows the routine's estimate behind this screen.
    @Binding var usesAuthoredLength: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var preview = CommandTempoPreviewPlayer()
    @State private var strumPreview = StrumPatternPreviewPlayer()
    @State private var showingDetail = false
    /// Disclosure state for the collapsible tempo + steps panel — purely local UI; the edits
    /// themselves write straight to the model (see the actions below).
    @State private var showSettings = false
    @State private var showSteps = false

    /// The strum pattern to audition, if this is a strumming or strum-&-chords drill (R5). Other
    /// templates have no strum rhythm, so they fall back to the plain command-tempo click.
    private var strumPattern: StrumPattern? {
        exercise.strumPattern ?? exercise.strumChordSheet?.strumPattern
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let pattern = exercise.strumPattern { StrumPatternPreview(pattern: pattern) }
                if let drill = exercise.fretboardDrill { FretboardExercisePreview(drill: drill) }
                if let progression = exercise.chordProgression {
                    ChordProgressionPreview(progression: progression)
                }
                if let sheet = exercise.strumChordSheet { StrumChordsPreview(sheet: sheet) }

                PracticeSettingsPanel(
                    expanded: $showSettings,
                    working: exercise.workingTempo, command: exercise.command,
                    reach: exercise.reachTempo, reachIsCustom: exercise.hasTargetOverride,
                    onStepWorking: { stepWorking(by: $0) }, onTypeWorking: { setWorking($0) },
                    onStepCommand: { stepCommand(by: $0) }, onTypeCommand: { setCommand($0) },
                    onStepReach: { stepReach(by: $0) }, onTypeReach: { setReach($0) },
                    onResetReach: resetReach,
                    includeBackoff: includeBackoffBinding, backoff: exercise.backoffTempo,
                    backoffIsCustom: exercise.hasBackoffOverride,
                    onStepBackoff: { stepBackoff(by: $0) }, onTypeBackoff: { setBackoff($0) },
                    onResetBackoff: resetBackoff,
                    stepsExpanded: $showSteps, warmupSteps: warmupStepsBinding,
                    reachSteps: reachStepsBinding, backoffSteps: backoffStepsBinding,
                    dwell: dwellBinding, dwellCaption: dwellCaption,
                    warmupStepBPM: warmupStepBPM, hasReach: hasReach,
                    tint: PocketColor.practice, onToggle: { haptic(.light) })
                RoutineStairs(plateaus: effectiveRamp.plateaus, command: effectiveRamp.command,
                              tint: PocketColor.practice)
                    .frame(height: 120)
                if plannedMinutes != nil {
                    BlockLengthControl(usesAuthoredLength: $usesAuthoredLength,
                                       runMinutes: runMinutes, authoredMinutes: authoredMinutes,
                                       tint: PocketColor.practice)
                }
                if let strumPattern {
                    PreviewAudioButton(isPlaying: strumPreview.isPlaying,
                                       idleTitle: "Hear the strum") {
                        strumPreview.toggle(pattern: strumPattern, signature: signature,
                                            bpm: exercise.command)
                    }
                } else {
                    PreviewAudioButton(isPlaying: preview.isPlaying,
                                       idleTitle: "Hear command tempo") {
                        preview.toggle(bpm: exercise.command, signature: signature)
                    }
                }
            }
            .padding(24)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop(); strumPreview.stop() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingDetail = true; haptic(.light) } label: {
                    Image(systemName: "info.circle")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("Exercise details")
            }
        }
        .sheet(isPresented: $showingDetail) { ExerciseDetailSheet(exercise: exercise) }
    }

    private var signature: TimeSignature {
        TimeSignature.forStored(beats: exercise.beatsPerBar, noteValue: exercise.noteValue,
                                accentBeats: exercise.accentBeats)
    }

    /// The staircase this block will actually run — the stored recipe, fitted to the block's allotted
    /// minutes when it has any (ADR 0129) and the player hasn't declined the fit (ADR 0130). The same
    /// expression `ExerciseRunView` hands the engine, so the preview and the run cannot disagree.
    /// Never written back.
    private var effectiveRamp: CommandRamp {
        guard !usesAuthoredLength, let plannedMinutes else { return exercise.ramp }
        return SessionEstimate.fitted(exercise.ramp, toMinutes: plannedMinutes,
                                      beatsPerBar: exercise.beatsPerBar)
    }

    /// Minutes this block takes as things stand — priced off the staircase above, so the note can
    /// never quote a length the drawing contradicts (ADR 0130).
    private var runMinutes: Int {
        SessionEstimate.minutes(forRamp: effectiveRamp, beatsPerBar: exercise.beatsPerBar)
    }

    /// Minutes the exercise's own stored recipe takes — the "your saved setting" half of the note.
    private var authoredMinutes: Int {
        SessionEstimate.minutes(forRamp: exercise.ramp, beatsPerBar: exercise.beatsPerBar)
    }

    // MARK: - Tempo + step edits (ADR 0077)
    //
    // Unlike the run screen — which holds edits in local state and commits on Start — the preview has
    // no Start to defer to, so each edit writes straight to the model through the canonical setters
    // (`promoteCommand`, `targetTempoOverride`, the ramp-shape fields) and saves. Steppers stay pure
    // (no haptic — `StepperButton` owns the hold-repeat feedback); typed setters carry the commit haptic.

    private func stepWorking(by delta: Int) {
        commit { exercise.workingTempo = clampWorking(exercise.workingTempo + delta) }
    }
    private func setWorking(_ value: Int) {
        commit { exercise.workingTempo = clampWorking(value) }; haptic(.light)
    }
    private func stepCommand(by delta: Int) {
        commit { exercise.promoteCommand(to: clampCommand(exercise.command + delta)) }
    }
    private func setCommand(_ value: Int) {
        commit { exercise.promoteCommand(to: clampCommand(value)) }; haptic(.light)
    }
    private func stepReach(by delta: Int) { commit { pinReach(exercise.reachTempo + delta) } }
    private func setReach(_ value: Int) { commit { pinReach(value) }; haptic(.light) }
    private func resetReach() { commit { exercise.targetTempoOverride = nil }; haptic(.light) }

    private func stepBackoff(by delta: Int) { commit { pinBackoff(exercise.backoffTempo + delta) } }
    private func setBackoff(_ value: Int) { commit { pinBackoff(value) }; haptic(.light) }
    private func resetBackoff() { commit { exercise.backoffTempoOverride = nil }; haptic(.light) }

    /// Working stays in range and never above command (it's the warm-up floor below the owned tempo).
    private func clampWorking(_ value: Int) -> Int {
        min(exercise.command, max(StandaloneMetronomeEngine.bpmRange.lowerBound, value))
    }

    /// Command stays in range and never below the working floor; a reach the new command has caught up
    /// to is dropped inside `promoteCommand` (ADR 0075).
    private func clampCommand(_ value: Int) -> Int {
        min(StandaloneMetronomeEngine.bpmRange.upperBound, max(exercise.workingTempo, value))
    }

    // MARK: - Ramp-shape (steps) — model-backed bindings for `PracticeSettingsPanel`

    /// Whether there's a climb above command to place reach stops on — gates the reach step row.
    private var hasReach: Bool { exercise.reachTempo > exercise.command }

    /// The warm-up step count the stored per-step BPM implies (the panel edits count, not BPM).
    private var currentWarmupSteps: Int {
        CommandRamp.intermediateSteps(working: exercise.workingTempo, command: exercise.command,
                                      stepBPM: exercise.rampStepBPM)
    }

    /// The BPM each warm-up step adds at the current count — the panel's warm-up caption.
    private var warmupStepBPM: Int {
        CommandRamp.warmupStepBPM(working: exercise.workingTempo, command: exercise.command,
                                  intermediateSteps: currentWarmupSteps)
    }

    /// Warm-up steps ↔ the stored `rampStepBPM`: reading derives the count, writing re-derives the
    /// per-step BPM the requested count implies (mirrors the run screen's persist).
    private var warmupStepsBinding: Binding<Int> {
        Binding(get: { currentWarmupSteps }, set: { newValue in
            commit {
                exercise.rampStepBPM = CommandRamp.warmupStepBPM(
                    working: exercise.workingTempo, command: exercise.command,
                    intermediateSteps: max(0, newValue))
            }
        })
    }

    private var reachStepsBinding: Binding<Int> {
        Binding(get: { exercise.rampReachSteps },
                set: { newValue in commit { exercise.rampReachSteps = max(0, newValue) } })
    }

    private var backoffStepsBinding: Binding<Int> {
        Binding(get: { exercise.rampBackoffSteps },
                set: { newValue in commit { exercise.rampBackoffSteps = max(0, newValue) } })
    }

    /// Whether the back-off tail is on (user-testing note 6), model-backed — toggling writes live.
    private var includeBackoffBinding: Binding<Bool> {
        Binding(get: { exercise.includeBackoff },
                set: { newValue in commit { exercise.includeBackoff = newValue } })
    }

    /// The command-plateau dwell (ADR 0078), model-backed — kept ≥ 1 (the command plateau must hold).
    private var dwellBinding: Binding<Int> {
        Binding(get: { max(1, exercise.dwellIntervals) },
                set: { newValue in commit { exercise.dwellIntervals = max(1, newValue) } })
    }

    /// Each dwell interval is `automatorDefaultBars` bars at command — the row's caption (ADR 0078),
    /// read off the **effective** ramp so it states the hold the run will play (ADR 0129).
    private var dwellCaption: String {
        "≈ \(effectiveRamp.dwellIntervals * StandaloneMetronomeEngine.automatorDefaultBars) bars"
    }

    /// Pin the reach strictly above command; landing back on the auto derivation clears the pin.
    private func pinReach(_ value: Int) {
        let upper = StandaloneMetronomeEngine.bpmRange.upperBound
        let clamped = min(upper, max(exercise.command + 1, value))
        exercise.targetTempoOverride = (clamped == exercise.derivedTarget) ? nil : clamped
    }

    /// Pin the back-off strictly below command (note 6); landing on the auto derivation clears the pin.
    private func pinBackoff(_ value: Int) {
        let lower = StandaloneMetronomeEngine.bpmRange.lowerBound
        let clamped = max(lower, min(exercise.command - 1, value))
        exercise.backoffTempoOverride = (clamped == exercise.derivedBackoff) ? nil : clamped
    }

    /// Apply a model mutation and persist it — the preview edits are live, not deferred.
    private func commit(_ change: () -> Void) {
        change()
        try? modelContext.save()
    }
}

// MARK: - Shared preview pieces

/// The tempo/speed anchor line shared by both previews: "working → command · reach", in the unit the
/// block trains in (BPM for exercises, % of original for loops). Internal, not private, because the
/// loop previews live in the `+Loop` split.
struct PreviewTempoReadout: View {
    let anchors: String
    let reach: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(anchors)
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
            Text("reach \(reach) · \(unit)")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The pill audio-preview button shared by both previews — an audition, not a run (ADR 0070).
/// Internal for the same reason as `PreviewTempoReadout`.
struct PreviewAudioButton: View {
    let isPlaying: Bool
    let idleTitle: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
            haptic(.light)
        } label: {
            Label(isPlaying ? "Stop preview" : idleTitle,
                  systemImage: isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                .font(.futura(.body, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(PocketColor.practice.opacity(0.14), in: Capsule())
        }
    }
}
