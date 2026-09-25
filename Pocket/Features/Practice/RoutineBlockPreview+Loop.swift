import SwiftData
import SwiftUI

/// The **loop** block previews (ADR 0071 R4b / ADR 0104 Slice 2) — the standard command-anchored
/// trainer preview and the ear-training one. Split out of `RoutineBlockPreview.swift` to keep each
/// file under the 400-line cap; the exercise preview stays there, and the shared pieces
/// (`PreviewTempoReadout` / `PreviewAudioButton`) stay with it.

/// A **pre-start preview** of a loop block (ADR 0071 R4b): its source song, the speed anchors +
/// staircase, the **Practice Settings** panel in percent-of-original units (ADR 0130 §4, closing
/// ADR 0077 §7), and a short **audio audition of the loop's actual audio** (the looping region at
/// command speed) — the loop analogue of the exercise preview.
///
/// Like its exercise counterpart it has **no Start to defer to**, so each tempo edit writes straight
/// to the loop through the canonical setters and saves (ADR 0077 §3). ADR 0077's rule — *the library
/// is the only full editor; in a routine the only editable knob is tempo* — now reads the same for
/// both unit kinds; a loop block previously had no tempo controls at all.
struct LoopBlockPreview: View {
    let loop: Loop
    /// Minutes a generated session allotted this block, or `nil` when hand-authored (ADR 0129).
    let plannedMinutes: Int?
    /// The block's opt-out from the session's fit (ADR 0130) — bound to the `RoutineItem`.
    @Binding var usesAuthoredLength: Bool
    /// Whether this block captures a take while it runs (ADR 0179) — bound to the `RoutineItem`, so
    /// flipping it here is what a marked block reads at run time.
    @Binding var recordsTake: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var preview: LoopAudioPreviewPlayer
    /// Disclosure state for the collapsible phase rows — purely local UI; the edits themselves write
    /// straight to the model.
    @State private var showSettings = false
    /// The open phase row (ADR 0221 D1), whose bars the staircase lights.
    @State private var openPhase: RampPhase? = .command

    init(loop: Loop, plannedMinutes: Int? = nil, usesAuthoredLength: Binding<Bool>,
         recordsTake: Binding<Bool>) {
        self.loop = loop
        self.plannedMinutes = plannedMinutes
        _usesAuthoredLength = usesAuthoredLength
        _recordsTake = recordsTake
        _preview = State(initialValue: LoopAudioPreviewPlayer(loop: loop))
    }

    /// The staircase this block will actually run — the loop's recipe, fitted to its allotted minutes
    /// by stretching the passes at command (ADR 0129 as amended) unless the player declined the fit
    /// (ADR 0130), matching `LoopRunView.routine`.
    private var effectiveRamp: CommandRamp {
        guard !usesAuthoredLength, let plannedMinutes else { return loop.ramp }
        return LoopEstimate.fitted(loop.ramp, toMinutes: plannedMinutes,
                                   regionSeconds: loop.regionSeconds)
    }

    /// Minutes this block takes as things stand — priced off the staircase above, so the length note
    /// can never quote a figure the drawing contradicts.
    private var runMinutes: Int {
        LoopEstimate.minutes(forRamp: effectiveRamp, regionSeconds: loop.regionSeconds)
    }

    /// Minutes the loop's own stored recipe takes — the "your saved setting" half of the note.
    private var authoredMinutes: Int {
        LoopEstimate.minutes(forRamp: loop.ramp, regionSeconds: loop.regionSeconds)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let song = loop.song {
                    VStack(spacing: 4) {
                        Text(song.title.isEmpty ? "Untitled song" : song.title)
                            .font(.futura(.title3, weight: .semibold))
                            .foregroundStyle(PocketColor.textPrimary)
                        if !song.artist.isEmpty {
                            Text(song.artist)
                                .font(.futura(.subheadline))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }

                PreviewTempoReadout(anchors: anchors, reach: shownReach, unit: "of original")
                settingsPanel
                RoutineStairs(plateaus: effectiveRamp.plateaus, command: effectiveRamp.command,
                              tint: PocketColor.practice, unit: .percent,
                              highlightedPhase: showSettings ? openPhase : nil,
                              lengthLine: RunLength.loop(effectiveRamp,
                                                         regionSeconds: loop.regionSeconds))
                if plannedMinutes != nil {
                    BlockLengthControl(usesAuthoredLength: $usesAuthoredLength,
                                       runMinutes: runMinutes, authoredMinutes: authoredMinutes,
                                       tint: PocketColor.practice)
                }
                // Unconditional, unlike the length control above — that one only speaks when a
                // session sized the block, but any block is worth hearing back (ADR 0179).
                BlockRecordControl(recordsTake: $recordsTake, tint: PocketColor.practice)
                if preview.isUnavailable {
                    Text("Audio unavailable — the song file couldn't be found.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    PreviewAudioButton(isPlaying: preview.isPlaying,
                                       idleTitle: "Hear the loop") { preview.toggle() }
                }
            }
            .padding(24)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(loop.name.isEmpty ? "Loop" : loop.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }

    // MARK: - The tempo readout

    /// `70% → 85%`, or just `85%` when the run opens at command — the climb the run actually plays.
    private var anchors: String {
        let shape = loop.runShape
        let tempos = loop.rampTempos
        guard shape.includeWarmup, tempos.hasRoom(for: .warmup) else { return "\(tempos.command)%" }
        return "\(tempos.working)% → \(tempos.command)%"
    }

    /// The reach, or `nil` when Reach is off — the readout then drops it, as the library row does
    /// (ADR 0221 D6).
    private var shownReach: String? { loop.includeReach ? "\(loop.rampTempos.reach)%" : nil }

    // MARK: - Practice Settings (ADR 0130 §4 — closes ADR 0077 §7)
    //
    // The run screen's phase rows (ADR 0221 D8), in percent and passes, wired to the model rather than
    // to local edit state: this surface has no Start to commit on, so every edit writes through and
    // saves.

    /// The command hold it reports as played is read off `effectiveRamp`, so in a generated session it
    /// describes the ramp fitted to the block (ADR 0129).
    private var settingsPanel: some View {
        PracticeSettingsPanel(
            expanded: $showSettings, openPhase: $openPhase, shape: shapeBinding,
            startAt: startAtControl, command: commandControl, reach: reachControl,
            settleAt: settleAtControl, playedDwell: effectiveRamp.dwellIntervals,
            tempoUnit: .percent, holdUnit: .passes,
            unitsPerInterval: LoopCommandRamp.passesPerInterval,
            tint: PocketColor.practice, onToggle: { haptic(.light) })
    }

    /// The warm-up floor as percent — read off `Loop.rampFloor`, the same derivation `loop.ramp` and
    /// `LoopRunView.seedIfNeeded` use, so the panel and the staircase below it agree (ADR 0129).
    private var working: Int { loop.rampTempos.working }
    private var command: Int { loop.rampTempos.command }
    private var reach: Int { loop.rampTempos.reach }
    /// The back-off floor: a pinned override when set, else the auto derivation below command.
    private var backoff: Int { loop.backoffPercent }

    // The tempo controls are typed properties rather than ternaries inside `body`, which the
    // type-checker can't resolve there (see `ExerciseBlockPreview`).

    private var startAtControl: PhaseTempoControl {
        PhaseTempoControl(value: working, onStep: { setWorking(working + $0) },
                          onType: { setWorking($0) })
    }

    private var commandControl: PhaseTempoControl {
        PhaseTempoControl(value: command, onStep: { setCommand(command + $0) },
                          onType: { setCommand($0) })
    }

    private var reachControl: PhaseTempoControl {
        var control = PhaseTempoControl(value: reach, onStep: { pinReach(reach + $0) },
                                        onType: { pinReach($0) })
        if loop.hasTargetOverride {
            control.onReset = { commit { loop.targetSpeedOverride = nil }; haptic(.light) }
        }
        return control
    }

    private var settleAtControl: PhaseTempoControl {
        var control = PhaseTempoControl(value: backoff, onStep: { pinBackoff(backoff + $0) },
                                        onType: { pinBackoff($0) })
        if loop.backoffSpeedOverride != nil {
            control.onReset = { commit { loop.backoffSpeedOverride = nil }; haptic(.light) }
        }
        return control
    }

    /// Move the warm-up floor. On an **un-measured** loop `command` *is* `speed`, so writing the floor
    /// alone would drag command down with it — the command is pinned where it already reads first, so
    /// the two decouple exactly as the run screen's seeded pair does.
    private func setWorking(_ value: Int) {
        commit {
            if !loop.hasMeasuredCommand { loop.promoteCommand(to: loop.command) }
            loop.speed = Double(clampPercent(min(command, value))) / 100
        }
        haptic(.light)
    }

    /// Command stays in range and never below the floor; a reach the new command has caught up to is
    /// dropped inside `promoteCommand` (ADR 0075).
    private func setCommand(_ value: Int) {
        commit { loop.promoteCommand(to: Double(clampPercent(max(working, value))) / 100) }
        haptic(.light)
    }

    /// Pin the reach strictly above command; landing back on the auto derivation clears the pin.
    private func pinReach(_ value: Int) {
        // Compared in percent, not in `×`: the panel edits whole percent, so a `Double` comparison
        // would miss the "landed back on auto" case by a rounding hair and leave a phantom pin.
        let auto = LoopCommandRamp.percent(loop.derivedTargetSpeed)
        let clamped = clampPercent(max(command + 1, value))
        commit { loop.targetSpeedOverride = clamped == auto ? nil : Double(clamped) / 100 }
        haptic(.light)
    }

    /// Pin the back-off floor strictly below command; landing on the auto derivation clears the pin.
    private func pinBackoff(_ value: Int) {
        let auto = TempoStretch.backoffBPM(command: command, target: reach, floor: working)
        let clamped = clampPercent(min(command - 1, value))
        commit { loop.backoffSpeedOverride = clamped == auto ? nil : Double(clamped) / 100 }
        haptic(.light)
    }

    private func clampPercent(_ value: Int) -> Int {
        min(LoopRunView.percentRange.upperBound, max(LoopRunView.percentRange.lowerBound, value))
    }

    // MARK: The run's shape — model-backed for `PracticeSettingsPanel`

    /// The phase switches, rungs and holds (ADR 0221 D8), read from and written straight back to the
    /// model. A write stores the holds in passes, which retires this loop's reps per step.
    private var shapeBinding: Binding<RunShape> {
        Binding(get: { loop.runShape }, set: { newValue in commit { loop.applyRunShape(newValue) } })
    }

    /// Apply a model mutation and persist it — the preview's edits are live, not deferred.
    private func commit(_ change: () -> Void) {
        change()
        try? modelContext.save()
    }
}
