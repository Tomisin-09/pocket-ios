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
    @Environment(\.modelContext) private var modelContext
    @State private var preview: LoopAudioPreviewPlayer
    /// Disclosure state for the collapsible tempo + steps panel — purely local UI; the edits
    /// themselves write straight to the model.
    @State private var showSettings = false
    @State private var showSteps = false

    init(loop: Loop, plannedMinutes: Int? = nil, usesAuthoredLength: Binding<Bool>) {
        self.loop = loop
        self.plannedMinutes = plannedMinutes
        _usesAuthoredLength = usesAuthoredLength
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

                PreviewTempoReadout(anchors: "\(effectiveRamp.working)% → \(effectiveRamp.command)%",
                                    reach: "\(effectiveRamp.target)%", unit: "of original")
                settingsPanel
                RoutineStairs(plateaus: effectiveRamp.plateaus, command: effectiveRamp.command,
                              tint: PocketColor.practice, unit: .percent)
                    .frame(height: 120)
                if plannedMinutes != nil {
                    BlockLengthControl(usesAuthoredLength: $usesAuthoredLength,
                                       runMinutes: runMinutes, authoredMinutes: authoredMinutes,
                                       tint: PocketColor.practice)
                }
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

    // MARK: - Practice Settings (ADR 0130 §4 — closes ADR 0077 §7)
    //
    // The percent-unit panel the loop run screen uses, wired to the model rather than to local edit
    // state: this surface has no Start to commit on, so every edit writes through and saves.

    private var settingsPanel: some View {
        LoopSettingsPanel(
            expanded: $showSettings,
            working: working, command: command, reach: reach,
            reachIsCustom: loop.hasTargetOverride,
            onStepWorking: { setWorking(working + $0) }, onTypeWorking: { setWorking($0) },
            onStepCommand: { setCommand(command + $0) }, onTypeCommand: { setCommand($0) },
            onStepReach: { pinReach(reach + $0) }, onTypeReach: { pinReach($0) },
            onResetReach: { commit { loop.targetSpeedOverride = nil }; haptic(.light) },
            includeBackoff: includeBackoffBinding, backoff: backoff,
            backoffIsCustom: loop.backoffSpeedOverride != nil,
            onStepBackoff: { pinBackoff(backoff + $0) }, onTypeBackoff: { pinBackoff($0) },
            onResetBackoff: { commit { loop.backoffSpeedOverride = nil }; haptic(.light) },
            repsPerStep: repsPerStepBinding, repsRange: LoopRunView.repsRange,
            stepsExpanded: $showSteps, warmupSteps: warmupStepsBinding,
            reachSteps: reachStepsBinding, backoffSteps: backoffStepsBinding,
            dwell: dwellBinding, dwellCaption: dwellCaption, warmupStepBPM: warmupStepPercent,
            hasReach: reach > command, tint: PocketColor.practice, onToggle: { haptic(.light) })
    }

    /// The warm-up floor as percent — read off `Loop.rampFloor`, the same derivation `loop.ramp` and
    /// `LoopRunView.seedIfNeeded` use, so the panel and the staircase below it agree (ADR 0129).
    private var working: Int { LoopCommandRamp.percent(loop.rampFloor) }
    private var command: Int { LoopCommandRamp.percent(loop.command) }
    private var reach: Int { LoopCommandRamp.percent(loop.targetSpeed) }

    /// The back-off floor: a pinned override when set, else the auto derivation below command — the
    /// percent-space rule `LoopRunView` applies.
    private var backoff: Int {
        loop.backoffSpeedOverride.map(LoopCommandRamp.percent)
            ?? TempoStretch.backoffBPM(command: command, target: reach, floor: working)
    }

    /// Each dwell interval holds `repsPerStep` passes (ADR 0078), read off the **effective** ramp so
    /// the caption states the hold the run will play.
    private var dwellCaption: String {
        "≈ \(effectiveRamp.dwellIntervals * max(1, loop.rampRepsPerStep)) passes"
    }

    private var warmupStepPercent: Int {
        CommandRamp.warmupStepBPM(working: working, command: command,
                                  intermediateSteps: loop.rampWarmupSteps)
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

    // MARK: Ramp-shape (steps) — model-backed bindings for `LoopSettingsPanel`

    private var includeBackoffBinding: Binding<Bool> {
        Binding(get: { loop.includeBackoff }, set: { new in commit { loop.includeBackoff = new } })
    }

    private var repsPerStepBinding: Binding<Int> {
        Binding(get: { max(LoopRunView.repsRange.lowerBound, loop.rampRepsPerStep) },
                set: { new in commit { loop.rampRepsPerStep = new } })
    }

    private var warmupStepsBinding: Binding<Int> {
        Binding(get: { loop.rampWarmupSteps }, set: { new in commit { loop.rampWarmupSteps = max(0, new) } })
    }

    private var reachStepsBinding: Binding<Int> {
        Binding(get: { loop.rampReachSteps }, set: { new in commit { loop.rampReachSteps = max(0, new) } })
    }

    private var backoffStepsBinding: Binding<Int> {
        Binding(get: { loop.rampBackoffSteps },
                set: { new in commit { loop.rampBackoffSteps = max(0, new) } })
    }

    /// The command-plateau dwell (ADR 0078), kept ≥ 1 — the command plateau must hold.
    private var dwellBinding: Binding<Int> {
        Binding(get: { max(1, loop.rampDwellIntervals) },
                set: { new in commit { loop.rampDwellIntervals = max(1, new) } })
    }

    /// Apply a model mutation and persist it — the preview's edits are live, not deferred.
    private func commit(_ change: () -> Void) {
        change()
        try? modelContext.save()
    }
}

/// The pre-start preview of an **ear-training** loop block (ADR 0104 Slice 2). Unlike `LoopBlockPreview`
/// there's no ramp/staircase — ear mode plays at a self-chosen tempo with no climb — so it shows the
/// loop + song, an "Ear training" label, and the same real-audio audition, so a player can confirm the
/// block before starting the routine.
struct EarLoopBlockPreview: View {
    let loop: Loop
    @State private var preview: LoopAudioPreviewPlayer

    init(loop: Loop) {
        self.loop = loop
        _preview = State(initialValue: LoopAudioPreviewPlayer(loop: loop))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 4) {
                    Text(loop.name.isEmpty ? "Untitled loop" : loop.name)
                        .font(.futura(.title3, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    if let song = loop.song {
                        Text(song.artist.isEmpty ? "from \(song.title)"
                                                 : "from \(song.title) · \(song.artist)")
                            .font(.futura(.subheadline))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                Label("Ear training — hum or sing it back", systemImage: "ear")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.journal)

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
        .navigationTitle(loop.name.isEmpty ? "Ear training" : loop.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }
}
