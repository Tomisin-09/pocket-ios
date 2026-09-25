import SwiftData
import SwiftUI

/// A **training run** on one song loop (ADR 0046, Phase B): the loop counterpart of
/// `ExerciseRunView`. A measured loop trains the same command-anchored staircase as an exercise —
/// warm up → dwell → reach → back off — but against its **time-stretched audio**, so the tempos
/// are percent-of-original (`×`) rather than absolute BPM. It owns a `LoopRunModel` (and through it
/// a private `PracticeAudioEngine`), so a Practice loop run is independent of the waveform screen.
///
/// Two modes on one screen, mirroring the exercise run:
/// - **Set up** (stopped): shape the run phase by phase — warm-up, command, reach, back off (ADR
///   0221 D8) — in % of original and passes, with the routine drawn as a staircase.
/// - **Running**: the live playback speed (climbing as the ramp steps the audio rate) over the
///   looping region, with pause / resume / stop.
///
/// **Start** commits the edits to the loop (`speed` = working, `promoteCommand` = command, the
/// shape) and hands the engine a `CommandRamp` (percent units, one pass per interval) via
/// `LoopRunModel`. Edits live in local state until Start or Save, so leaving discards them.
struct LoopRunView: View {
    let loop: Loop
    /// Routine-session chrome (progress, Skip, auto-advance) when a block in a routine; `nil` standalone.
    var routineContext: RoutineRunContext?
    @State var model: LoopRunModel
    @Environment(\.modelContext) var modelContext

    // Local edit state (percent of original), seeded on appear, committed only on Start.
    @State var working = 0
    @State var command = 0
    /// The run's shape — which phases play, their rungs and their holds in passes (ADR 0221 D8).
    /// Seeded from the loop, committed on Start / Save like the tempos.
    @State var shape = RunShape()
    /// A manually pinned **reach** (% of original), or `nil` to use the auto-derived reach
    /// (ADR 0075). Seeded from `loop.targetSpeedOverride`, committed on Start / Save. Always kept
    /// above `command`; auto-cleared locally when command is nudged up to it, mirroring the model.
    @State var targetOverride: Int?
    /// A manually pinned **backoff floor** (% of original), or `nil` for the auto derivation (note 6).
    /// Seeded from `loop.backoffSpeedOverride`, committed on Start / Save. Kept below `command`.
    @State var backoffOverride: Int?
    /// The top-level "Practice Settings" disclosure — collapsed by default so the run screen opens on
    /// the summary + staircase (parity with the exercise run); expands to the phase rows.
    @State var showSettings = false
    /// The open phase row (ADR 0221 D1) — Command to start, the one most often tuned.
    @State var openPhase: RampPhase? = .command
    /// Whether the routine count-in overlay is showing (routine mode only) — gates the run start.
    @State var showCountIn = false
    @State var seeded = false
    /// The practice journal sheet — authoring lives here now (ADR 0058), reachable from the nav bar.
    @State var showingJournal = false
    /// The compact mid-run capture sheet (ADR 0142) — reachable **always**, including while the audio
    /// is running and inside a routine, which is exactly where the full journal is not.
    @State var showingQuickNote = false
    /// The Takes sheet — relisten to practice-take recordings (ADR 0069, slice 3).
    @State var showingTakes = false
    /// The setup as last persisted — captured on seed and after each Save, so the Save Changes
    /// button shows only while the edits differ (ADR 0057). Every persisted field — the tempos, the
    /// pins and the shape — is tracked, so editing any of them arms Save Changes.
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
        LoopSetupState(working: working, command: command, shape: shape,
                       targetOverride: targetOverride, backoffOverride: backoffOverride)
    }
    private var isDirty: Bool { baseline.map { $0 != current } ?? false }

    /// Playback-speed bounds as integer percent — `TempoMath`'s axis, so this ceiling moves with the
    /// waveform slider and the automator ramp rather than diverging from them (ADR 0124).
    static let percentRange = TempoMath.percentRange

    init(loop: Loop, routineContext: RoutineRunContext? = nil) {
        self.loop = loop
        self.routineContext = routineContext
        _model = State(initialValue: LoopRunModel(loop: loop))
    }

    var isRunning: Bool { model.isRunning }
    private var showsReviewBar: Bool {
        PracticeReviewBar.isShown(isRunning: isRunning, inRoutine: routineContext != nil)
    }
    private var title: String { loop.name.isEmpty ? "Loop" : loop.name }

    var body: some View {
        // The wrapper is what lets the running note card scroll clear of the keyboard (N5) — the
        // composer is nested two levels down and reaches its scroll container through the environment.
        KeyboardFollowingScroll {
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
                                  currentIndex: model.currentPlateau(in: routine),
                                  highlightedPhase: showSettings ? openPhase : nil,
                                  lengthLine: RunLength.loop(routine,
                                                             regionSeconds: loop.regionSeconds))
                    if !isRunning, isDirty { saveChangesButton }
                    if isRunning { runNoteCard }
                    if showsReviewBar {
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
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Capture wherever the review bar's Journal isn't (ADR 0221 D7): while running, and inside
            // a routine, where there was once no way to write anything at all (ADR 0142).
            if !showsReviewBar {
                ToolbarItem(placement: .topBarTrailing) {
                    QuickJournalButton(isPresented: $showingQuickNote)
                }
            }
        }
        .routineSessionChrome(routineContext)
        .safeAreaInset(edge: .bottom) { transport }
        .overlay { if showCountIn { RoutineCountInOverlay(onComplete: countInFinished) } }
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        .onAppear { seedIfNeeded(); armIfBlockRecords() }
        .task { await model.loadIfNeeded(); maybeAutoStart() }
        .onChange(of: isRunning) { _, running in
            // Fires *after* the engine has already stopped and released the shared session, so this
            // finalises a take on the far side of that release. Safe only because `RecordingController`
            // holds a lease of its own while recording — don't "fix" it by reordering, there is
            // nothing here to reorder.
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
        // Presented over a live run on purpose: nothing here pauses the audio (ADR 0142).
        .sheet(isPresented: $showingQuickNote) {
            QuickJournalSheet(owner: .loop(loop))
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

    /// Inline capture **while the loop is playing** (ADR 0142). The trainer's running screen is one
    /// number, a caption and a staircase — there is room here, and the note you want is usually the
    /// one you'd otherwise lose between this pass and the Done screen. The sheet stays available in
    /// the nav bar for the drills whose running screen has no room (a fretboard board, a chord grid).
    private var runNoteCard: some View {
        JournalNoteComposer(owner: .loop(loop), kind: .note,
                            header: "Note this run",
                            placeholder: "What's working, what's fighting back?",
                            style: .card)
    }

    // MARK: - Setup (stopped)

    /// The collapsible **Practice Settings** panel, a row per phase in % of original and passes (ADR
    /// 0221 D8) — the exercise run's panel, so the two can't word a phase differently. The edits
    /// still live in this view's state until Start or Save (ADR 0057).
    ///
    /// The command hold it reports as played is read off `routine`, not `shape`, so inside a generated
    /// session it describes the ramp fitted to the block rather than the stored recipe (ADR 0129).
    private var practiceSettings: some View {
        PracticeSettingsPanel(
            expanded: $showSettings, openPhase: $openPhase, shape: $shape,
            startAt: PhaseTempoControl(value: working, onStep: { adjustWorking(by: $0) },
                                       onType: { setWorking($0) }),
            command: PhaseTempoControl(value: command, onStep: { adjustCommand(by: $0) },
                                       onType: { setCommand($0) }),
            reach: reachControl, settleAt: settleAtControl,
            playedDwell: routine.dwellIntervals,
            tempoUnit: .percent, holdUnit: .passes,
            unitsPerInterval: LoopCommandRamp.passesPerInterval,
            tint: PocketColor.practice, onToggle: { haptic(.light) })
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

    // The bottom transport lives in `LoopRunView+Transport.swift` — this file's struct body is
    // at the 250-line cap CI's `--strict` lint enforces.
}

#Preview("Loop run") {
    let loop = Loop(name: "Chorus solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
    loop.commandTempo = 0.85
    return NavigationStack { LoopRunView(loop: loop) }
        .preferredColorScheme(.dark)
}
