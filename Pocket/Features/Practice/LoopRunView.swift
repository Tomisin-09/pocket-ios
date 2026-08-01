import SwiftData
import SwiftUI

/// A **training run** on one song loop (ADR 0046, Phase B): the loop counterpart of
/// `ExerciseRunView`. A measured loop trains the same command-anchored staircase as an exercise —
/// warm up → dwell → reach → back off — but against its **time-stretched audio**, so the tempos
/// are percent-of-original (`×`) rather than absolute BPM. It owns a `LoopRunModel` (and through it
/// a private `PracticeAudioEngine`), so a Practice loop run is independent of the waveform screen.
///
/// Two modes on one screen, mirroring the exercise run:
/// - **Set up** (stopped): edit the warm-up **working** floor and owned **command** (as % of
///   original), with the derived **reach**, the warm-up/reach/back-up step granularity, and the
///   routine drawn as a staircase. A one-tap **promote** ratchets command up to the reach.
/// - **Running**: the live playback speed (climbing as the ramp steps the audio rate) over the
///   looping region, with pause / resume / stop.
///
/// **Start** commits the edits to the loop (`speed` = working, `promoteCommand` = command) and
/// hands the engine a `CommandRamp` (percent units, `.seconds` intervals) via `LoopRunModel`. Edits
/// live in local state until Start, so leaving without starting discards them.
struct LoopRunView: View {
    let loop: Loop
    /// Routine-session chrome (progress, Skip, auto-advance) when a block in a routine; `nil` standalone.
    var routineContext: RoutineRunContext?
    @State var model: LoopRunModel
    @Environment(\.modelContext) var modelContext

    // Local edit state (percent of original), seeded on appear, committed only on Start.
    @State var working = 0
    @State var command = 0
    @State var steps = 0
    @State var reachSteps = 0
    @State var backoffSteps = 0
    @State var repsPerStep = LoopCommandRamp.defaultRepsPerStep
    /// How many intervals the command plateau dwells — the consolidation hold, now user-tunable
    /// (ADR 0078). Seeded from the loop, committed on Start / Save like the other ramp fields.
    @State var dwell = LoopCommandRamp.defaultDwellIntervals
    /// A manually pinned **reach** (% of original), or `nil` to use the auto-derived reach
    /// (ADR 0075). Seeded from `loop.targetSpeedOverride`, committed on Start / Save. Always kept
    /// above `command`; auto-cleared locally when command is nudged up to it, mirroring the model.
    @State var targetOverride: Int?
    /// Whether the ramp backs off below command after the summit (user-testing note 6). Seeded from
    /// `loop.includeBackoff`, committed on Start / Save. Default on.
    @State var includeBackoff = true
    /// A manually pinned **backoff floor** (% of original), or `nil` for the auto derivation (note 6).
    /// Seeded from `loop.backoffSpeedOverride`, committed on Start / Save. Kept below `command`.
    @State var backoffOverride: Int?
    /// The top-level "Practice Settings" disclosure — collapsed by default so the run screen opens on
    /// the summary + staircase (parity with the exercise run); expands to reveal tempos/reps/Steps.
    @State var showSettings = false
    @State var showSteps = false
    /// Whether the routine count-in overlay is showing (routine mode only) — gates the run start.
    @State var showCountIn = false
    @State var seeded = false
    /// The practice journal sheet — authoring lives here now (ADR 0058), reachable from the nav bar.
    @State var showingJournal = false
    /// The Takes sheet — relisten to practice-take recordings (ADR 0069, slice 3).
    @State var showingTakes = false
    /// The setup as last persisted — captured on seed and after each Save, so the Save Changes
    /// button shows only while the edits differ (ADR 0057). All six persisted fields — the two
    /// tempos and the four ramp-shape controls (ADR 0057 follow-up) — are tracked, so editing any
    /// of them arms Save Changes.
    @State var baseline: LoopSetupState?
    /// When the current run started, or `nil` when nothing is running — the practice log's clock
    /// (ADR 0117). Stamped on Start and consumed by the natural-completion hook, so a run stopped by
    /// hand never logs: the log records *completed* unit-runs.
    @State var runStartedAt: Date?
    /// Set from `model.onFinished` on natural completion of a standalone run; drives the post-run
    /// completion screen (ADR 0082, loop parity with ADR 0079). Never set in a routine — there the
    /// ramp's completion advances the session instead.
    @State var completion: RunCompletion?
    /// Practice-take recording over this loop (ADR 0069, slice 2) — mic-only capture that rides the
    /// running transport, owned so it can be finalized on run-stop / screen exit.
    @State var recorder = RecordingController()

    var current: LoopSetupState {
        LoopSetupState(working: working, command: command, warmupSteps: steps,
                       reachSteps: reachSteps, backoffSteps: backoffSteps, repsPerStep: repsPerStep,
                       dwell: dwell, targetOverride: targetOverride,
                       includeBackoff: includeBackoff, backoffOverride: backoffOverride)
    }
    private var isDirty: Bool { baseline.map { $0 != current } ?? false }

    static let repsRange = 1...8

    /// Playback-speed bounds as integer percent — `TempoMath`'s axis, so this ceiling moves with the
    /// waveform slider and the automator ramp rather than diverging from them (ADR 0124).
    static let percentRange = TempoMath.percentRange

    init(loop: Loop, routineContext: RoutineRunContext? = nil) {
        self.loop = loop
        self.routineContext = routineContext
        _model = State(initialValue: LoopRunModel(loop: loop))
    }

    /// The **auto** reach (% of original) derived from the (local) command — proportional + clamped
    /// via the `×`-unit `TempoStretch`, mapped back to percent. The fallback for reset-to-auto.
    var autoReach: Int {
        LoopCommandRamp.percent(TempoStretch.targetSpeed(forCommand: Double(command) / 100))
    }

    /// The **effective** reach (% of original): a pinned override when set, else the auto reach
    /// (ADR 0075). Every surface here reads this — the staircase summit, promote, summary. Internal
    /// (not private) so the `+Actions` extension can snapshot it for the post-run offer (ADR 0082).
    var reach: Int { targetOverride ?? autoReach }

    /// The **auto** backoff floor (% of original) for the current tempos — the reset-to-auto fallback
    /// (user-testing note 6). The same percent-space derivation `CommandRamp` uses when unpinned.
    var autoBackoff: Int { TempoStretch.backoffBPM(command: command, target: reach, floor: working) }

    /// The **effective** backoff floor (% of original): a pinned override when set, else the auto value.
    var backoff: Int { backoffOverride ?? autoBackoff }

    /// The warm-up step size (percent points) the chosen number of intermediate stops implies.
    private var stepPercent: Int {
        CommandRamp.warmupStepBPM(working: working, command: command, intermediateSteps: steps)
    }

    /// The routine the current edits describe — the staircase preview and the exact `CommandRamp`
    /// (percent units) handed to the run on Start.
    ///
    /// Inside a **generated** session the block's allotted minutes win: the ramp is fitted to the slot
    /// by stretching the dwell — for a loop, more passes at command — bounded against the authored
    /// dwell (ADR 0129 as amended). Loops were left out of the block model entirely at first: a loop
    /// block was allotted a slot and ignored it. Nothing is written back; `persist()` saves the edit
    /// state, never the fitted value.
    var routine: CommandRamp {
        let authored = CommandRamp(working: working, command: command, target: reach,
                                   stepBPM: stepPercent, intervalCount: max(1, repsPerStep),
                                   unit: .bars, dwellIntervals: max(1, dwell),
                                   includeBackoff: includeBackoff, reachSteps: reachSteps,
                                   backoffSteps: backoffSteps, backoffOverride: backoffOverride)
        guard let planned = routineContext?.plannedMinutes else { return authored }
        return LoopEstimate.fitted(authored, toMinutes: planned,
                                   regionSeconds: loop.regionSeconds)
    }

    private var hasReach: Bool { reach > command }

    /// The dwell row's caption — each interval holds `repsPerStep` loop passes, so N intervals ≈
    /// N×reps passes at command (ADR 0078). Reads the **effective** dwell off `routine`, so inside a
    /// generated session it describes the fitted ramp rather than the stored recipe (ADR 0129) — the
    /// caption can't claim a hold the run won't play.
    private var dwellCaption: String {
        "≈ \(routine.dwellIntervals * max(1, repsPerStep)) passes"
    }

    var isRunning: Bool { model.isRunning }
    private var title: String { loop.name.isEmpty ? "Loop" : loop.name }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if isRunning {
                    liveReadout
                    RecordingStatusView(recorder: recorder)
                } else {
                    practiceSettings
                }
                RoutineStairs(plateaus: routine.plateaus, command: routine.command,
                              tint: PocketColor.practice, unit: .percent,
                              currentIndex: model.currentPlateau(in: routine))
                if !isRunning, isDirty { saveChangesButton }
                if !isRunning, routineContext == nil {
                    PracticeReviewBar(journalCount: loop.journal.count,
                                      takesCount: loop.recordings.count,
                                      onJournal: { showingJournal = true },
                                      onTakes: { showingTakes = true })
                        .padding(.top, 4)
                }
            }
            .padding(24)
            .animation(.easeInOut(duration: 0.2), value: isDirty)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .routineSessionChrome(routineContext)
        .safeAreaInset(edge: .bottom) { transport }
        .overlay { if showCountIn { RoutineCountInOverlay(onComplete: countInFinished) } }
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        .onAppear(perform: seedIfNeeded)
        .task { await model.loadIfNeeded(); maybeAutoStart() }
        .onChange(of: isRunning) { _, running in
            if !running { finishTakeIfNeeded() }   // run stopped ⇒ never leave a take recording
        }
        .onDisappear { finishTakeIfNeeded(); model.stop() }
        .sheet(isPresented: $showingJournal) {
            JournalSheet(owner: .loop(loop),
                         onAdd: addJournalEntry,
                         onUpdate: { entry, text, kind in
                             JournalWriter.update(entry, text: text, kind: kind)
                             try? modelContext.save()
                         },
                         onDelete: { entry in
                             JournalWriter.delete(entry, from: modelContext)
                             try? modelContext.save(); haptic(.light)
                         })
        }
        .sheet(isPresented: $showingTakes) {
            TakesSheet(owner: .loop(loop), onDelete: deleteTake)
        }
        .fullScreenCover(item: $completion) { finished in
            // Reuse the routine block's Done screen for a standalone loop finish (ADR 0082, mirroring
            // ADR 0079 for exercises) — completion beat + optional mastery + note + the editable
            // command revision, minus the "Up next" card (nothing follows a solo run). Both
            // directions are passed; the mastery tap picks between them (ADR 0134).
            RoutineBlockDoneView(title: title,
                                 initialMastery: loop.mastery,
                                 anchors: completionAnchors(finished), unit: .percent,
                                 isLast: true, upNext: nil) { mastery, note, kind, revision in
                commitCompletion(mastery: mastery, note: note, kind: kind, revision: revision)
            }
        }
    }

    /// Write a new entry, snapshotting the loop's current mastery + command tempo (ADR 0058).
    private func addJournalEntry(_ text: String, _ kind: EntryKind) {
        if JournalWriter.add(to: .loop(loop), text: text, kind: kind, into: modelContext) {
            try? modelContext.save()
            haptic(.light)
        }
    }

    // MARK: - Live readout (running)

    private var liveReadout: some View {
        VStack(spacing: 18) {
            VStack(spacing: 2) {
                Text("\(model.currentPercent)%")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                Text("of original tempo")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                Text("loop \(model.elapsedReps + 1)")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.practice)
                    .contentTransition(.numericText())
            }
            if model.isLoading {
                ProgressView().tint(PocketColor.practice)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Playing at \(model.currentPercent) percent of original tempo")
    }

    // MARK: - Setup (stopped)

    /// The collapsible Practice Settings panel — tempos + reps + Steps behind one disclosure, so the
    /// loop run opens on the summary + staircase (parity with the exercise run, ADR 0071).
    private var practiceSettings: some View {
        LoopSettingsPanel(
            expanded: $showSettings,
            working: working, command: command, reach: reach,
            reachIsCustom: targetOverride != nil,
            onStepWorking: { adjustWorking(by: $0) }, onTypeWorking: { setWorking($0) },
            onStepCommand: { adjustCommand(by: $0) }, onTypeCommand: { setCommand($0) },
            onStepReach: { adjustReach(by: $0) }, onTypeReach: { setReach($0) },
            onResetReach: resetReach,
            includeBackoff: $includeBackoff, backoff: backoff, backoffIsCustom: backoffOverride != nil,
            onStepBackoff: { adjustBackoff(by: $0) }, onTypeBackoff: { setBackoff($0) },
            onResetBackoff: resetBackoff,
            repsPerStep: $repsPerStep, repsRange: Self.repsRange,
            stepsExpanded: $showSteps, warmupSteps: $steps, reachSteps: $reachSteps,
            backoffSteps: $backoffSteps, dwell: $dwell, dwellCaption: dwellCaption,
            warmupStepBPM: stepPercent,
            hasReach: hasReach, tint: PocketColor.practice, onToggle: { haptic(.light) })
    }

    /// Persist the tuning without starting a run (ADR 0057) — shown only while the setup differs
    /// from what's stored. A subtle filled capsule, distinct from the outlined Promote and the
    /// filled Start pill. Leaving still discards *unsaved* edits.
    private var saveChangesButton: some View {
        Button(action: saveChanges) {
            Label("Save changes", systemImage: "checkmark.circle.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(PocketColor.practiceCircleWash))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save changes to this loop")
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: 14) {
            if isRunning {
                Button { model.stop(); haptic(.medium) } label: {
                    Image(systemName: "stop.fill")
                        .font(.futura(.title3))
                        .foregroundStyle(PocketColor.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(PocketColor.textSecondary.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and reset")
                Button { model.toggle(); haptic(.medium) } label: {
                    Label(model.transport == .playing ? "Pause" : "Resume",
                          systemImage: model.transport == .playing ? "pause.fill" : "play.fill")
                        .pocketRunButton
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    if model.loadFailed {
                        Text("Couldn't load this song's audio — the file may have moved or been deleted.")
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    HStack(spacing: 14) {
                        Button(action: startTapped) {
                            Label("Start training", systemImage: "play.fill").pocketRunButton
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isLoading || model.loadFailed)
                        .accessibilityLabel("Start training routine")
                        // Recording is a standalone-practice feature — routine blocks stay focused
                        // (ADR 0071/0077), matching the Takes/Journal bar's `routineContext == nil` gate.
                        if routineContext == nil {
                            RecordArmToggle(recorder: recorder,
                                            disabled: model.isLoading || model.loadFailed)
                        }
                    }
                    RecordSetupHint(recorder: recorder)
                }
                .animation(.easeInOut(duration: 0.2), value: recorder.isArmed)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(PocketColor.background.opacity(0.95))
    }
}

#Preview("Loop run") {
    let loop = Loop(name: "Chorus solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
    loop.commandTempo = 0.85
    return NavigationStack { LoopRunView(loop: loop) }
        .preferredColorScheme(.dark)
}
