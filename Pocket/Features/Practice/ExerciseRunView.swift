import SwiftData
import SwiftUI

/// A **training run** on one exercise (ADR 0046, Phase A): the screen reached by tapping a unit in
/// Practice. It **owns its own `StandaloneMetronomeEngine`**, so a drill here never disturbs the
/// metronome screen. Two modes: **set up** (stopped) edits the three tempos — working floor, command,
/// derived reach — plus warm-up steps, drawn as a staircase; **running** shows the live BPM and the
/// beat/template surface. **Start** commits the edits and hands the engine a `CommandRamp`
/// (`engine.run(ramp:)`); edits are held in local state until then, so leaving discards. Promotion is
/// no longer a pre-run button — a run that finishes *naturally* lands on a post-run completion screen
/// that offers to move command up to the reach (ADR 0079).
struct ExerciseRunView: View {
    let exercise: Exercise
    /// Routine-session chrome (progress, Skip, auto-advance) when a block in a routine; `nil` standalone.
    var routineContext: RoutineRunContext?
    @State var engine = StandaloneMetronomeEngine()
    @Environment(\.modelContext) var modelContext
    /// Red Moon Pro entitlement + the shared paywall (ADR 0112); safe preview defaults (free / no-op).
    /// Editing a drill's shape is authoring, so it's gated even for a free-taste preset the player may
    /// *run* (they reach this screen) — the "run the freebie, don't edit it" rule.
    @Environment(\.isPro) var isPro
    @Environment(\.presentPaywall) var presentPaywall
    /// The global note-caption preference (set from the exercise editors) — read so the live board
    /// captions notes the same way the creation preview did.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }

    // Local edit state — seeded from the exercise on appear, committed only on Start.
    @State var working = 0
    @State var command = 0
    @State var steps = 0
    @State var reachSteps = 0
    @State var backoffSteps = 0
    /// How many intervals the command plateau holds — the consolidation dwell, now user-tunable
    /// (ADR 0078). Seeded from the exercise, committed on Start / Save like the other ramp fields.
    @State var dwell = StandaloneMetronomeEngine.automatorDefaultDwell
    /// A manually pinned **reach** (BPM), or `nil` to use the auto-derived reach (ADR 0075). Seeded
    /// from `exercise.targetTempoOverride`, committed on Start / Save. Always kept above `command`;
    /// auto-cleared locally when command is nudged up to it, mirroring the model.
    @State var targetOverride: Int?
    /// Whether the routine backs off below command after the summit (user-testing note 6). Seeded
    /// from `exercise.includeBackoff`, committed on Start / Save. Default on.
    @State var includeBackoff = true
    /// A manually pinned **backoff floor** (BPM), or `nil` to use the auto derivation (note 6).
    /// Seeded from `exercise.backoffTempoOverride`, committed on Start / Save. Kept below `command`.
    @State var backoffOverride: Int?
    @State var showSteps = false
    /// The top-level "Practice Settings" disclosure — collapsed by default (V1 feedback).
    @State var showSettings = false
    @State var signature: TimeSignature = .standard
    /// Whether the meter sheet is showing (setup only — the picker is hidden once a run starts).
    @State private var showingSignaturePicker = false
    @State var seeded = false
    /// The practice journal sheet — authoring lives here now (ADR 0058), reachable from the nav bar.
    @State var showingJournal = false
    /// The compact mid-run capture sheet (ADR 0142) — reachable **always**, including while the ramp
    /// is running and inside a routine, which is exactly where the full journal is not.
    @State var showingQuickNote = false
    /// The Takes sheet — relisten to practice-take recordings (ADR 0069).
    @State var showingTakes = false
    /// Practice-take recording over this exercise (ADR 0069) — mic-only capture armed before the run.
    @State var recorder = RecordingController()
    /// The exercise detail/reference sheet (V1 feedback #2) — an ⓘ in the nav bar opens it.
    @State var showingDetail = false
    @State var songRoute = LinkedSongRoute()
    /// The content/shape editor sheet (ADR 0077) — an "Edit shape" button on the board opens it.
    /// Library-only: in a routine an exercise is tempo-only, so the button is never shown there.
    @State var showingShape = false
    /// The setup as it was last persisted — captured on seed and after each Save, so the Save
    /// Changes button shows only while the current edits differ from what's stored (ADR 0057).
    @State var baseline: ExerciseSetupState?
    /// When the current run started, or `nil` when nothing is running — the practice log's clock
    /// (ADR 0117). Stamped on Start and consumed by the natural-completion hook, so a run stopped by
    /// hand simply never logs: the log records *completed* unit-runs, and an aborted one has no honest
    /// length to claim.
    @State var runStartedAt: Date?
    /// A just-finished **standalone** run awaiting the post-run promote offer (ADR 0079), or `nil`.
    /// Set from `onRampFinished` on natural completion; drives the completion screen. Never set in a
    /// routine — there the player's Done screen carries the offer instead (ADR 0079 §7).
    @State var completion: RunCompletion?

    /// The persistable setup as it stands now — what Start / Save would write.
    var current: ExerciseSetupState {
        ExerciseSetupState(working: working, command: command, steps: steps,
                           reachSteps: reachSteps, backoffSteps: backoffSteps, dwell: dwell,
                           signature: signature, targetOverride: targetOverride,
                           includeBackoff: includeBackoff, backoffOverride: backoffOverride)
    }

    /// True when the setup has unsaved edits — drives the Save Changes button.
    private var isDirty: Bool { baseline.map { $0 != current } ?? false }

    /// The **auto** reach derived from the (local) command — proportional + clamped (ADR 0045); the
    /// fallback for reset-to-auto.
    var autoReach: Int { TempoStretch.targetBPM(forCommand: command) }

    /// The **effective** reach: a pinned override when set, else the auto reach (ADR 0075). Read by
    /// the run-setup extension to snapshot the reach for the post-run promote offer (ADR 0079).
    var reach: Int { targetOverride ?? autoReach }

    /// Whether there's a climb above command to put intermediate reach stops on.
    private var hasReach: Bool { reach > command }

    var isRunning: Bool { engine.transport != .stopped }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if isRunning {
                    liveReadout
                    RecordingStatusView(recorder: recorder)
                } else {
                    // Shape editing lives on the board now (ADR 0077), not on the ⓘ reference sheet —
                    // tucked into each preview card's header. Library-only: in a routine an exercise
                    // is tempo-only, so no edit affordance (the closure stays `nil`).
                    if let pattern = exercise.strumPattern {
                        StrumPatternPreview(pattern: pattern, editShape: editShapeAction)
                    }
                    if let drill = exercise.fretboardDrill {
                        FretboardExercisePreview(drill: drill, editShape: editShapeAction)
                    }
                    if let progression = exercise.chordProgression {
                        ChordProgressionPreview(progression: progression, editShape: editShapeAction)
                    }
                    if let sheet = exercise.strumChordSheet {
                        StrumChordsPreview(sheet: sheet, editShape: editShapeAction)
                    }
                    // Practice Settings (collapsed by default) in every context. In a routine it's the
                    // *ramp shape* you tune — tempo + steps; the library-only affordances (promote,
                    // Save, journal, meter) still drop out below (ADR 0077).
                    practiceSettings
                }
                RoutineStairs(plateaus: routine.plateaus, command: command, tint: PocketColor.practice,
                              currentIndex: isRunning ? engine.currentRampPlateau : nil,
                              nextIndex: isRunning ? engine.warningNextPlateau : nil)
                if !isRunning, routineContext == nil, isDirty { saveChangesButton }
                if !isRunning, routineContext == nil {
                    PracticeReviewBar(journalCount: exercise.journal.count,
                                      takesCount: exercise.recordings.count,
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
        .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Meter is part of the full editor — in a routine it's fixed, tempo is the only knob (ADR 0077).
            if !isRunning, routineContext == nil {
                ToolbarItem(placement: .topBarTrailing) { signaturePicker }
            }
            // Capture, in every state (ADR 0142) — a running drill and a routine block are where
            // most notes are owed, and until now both were places you couldn't write one.
            ToolbarItem(placement: .topBarTrailing) {
                QuickJournalButton(isPresented: $showingQuickNote)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingDetail = true; haptic(.light) } label: {
                    Image(systemName: "info.circle")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("Exercise details")
            }
        }
        .routineSessionChrome(routineContext)
        .linkedSongPlayer($songRoute)
        .safeAreaInset(edge: .bottom) { transport }
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        // Arm **before** `maybeAutoStart()`, never after — see `armIfBlockRecords()`.
        .onAppear { seedIfNeeded(); armIfBlockRecords(); maybeAutoStart() }
        .onChange(of: isRunning) { _, running in
            // Runs after the engine stopped and released the shared session — see the twin comment in
            // `LoopRunView`. `RecordingController`'s own lease is what keeps the take alive across it.
            if !running { finishTakeIfNeeded() }   // run stopped ⇒ never leave a take recording
        }
        .onDisappear { finishTakeIfNeeded(); engine.stop() }
        .sheet(isPresented: $showingJournal) {
            JournalSheet(owner: .exercise(exercise),
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
        // Presented over a live run on purpose: nothing here pauses the engine (ADR 0142).
        .sheet(isPresented: $showingQuickNote) {
            QuickJournalSheet(owner: .exercise(exercise))
        }
        .sheet(isPresented: $showingTakes) {
            TakesSheet(owner: .exercise(exercise), onDelete: deleteTake)
        }
        .sheet(isPresented: $showingDetail, onDismiss: { songRoute.promote() },
               content: { ExerciseDetailSheet(exercise: exercise, onOpenSong: songTapHandler) })
        .sheet(isPresented: $showingShape) {
            ExerciseShapeSheet(exercise: exercise)
        }
        .fullScreenCover(item: $completion) { finished in
            // Reuse the routine block's Done screen for a standalone finish (ADR 0079) — the same
            // completion beat + optional mastery + note + the editable command revision, minus the
            // "Up next" card (nothing follows a solo run). One integrated surface, not a bespoke
            // second one. Both directions are passed; the mastery tap picks between them (ADR 0134).
            RoutineBlockDoneView(title: exercise.name.isEmpty ? "Exercise" : exercise.name,
                                 initialMastery: exercise.mastery,
                                 anchors: completionAnchors(finished),
                                 isLast: true, upNext: nil) { mastery, note, kind, revision in
                commitCompletion(mastery: mastery, note: note, kind: kind, revision: revision)
            }
        }
    }

    // MARK: - Live readout (running)

    private var liveReadout: some View {
        VStack(spacing: 18) {
            if let countdown = engine.automatorCountdown {
                // Count-in before the climb engages (ADR 0052) — the beat dots keep flashing below.
                VStack(spacing: 2) {
                    Text("\(countdown)")
                        .font(.pocketMono(.largeTitle))
                        .foregroundStyle(PocketColor.practice)
                        .contentTransition(.numericText())
                    Text("Counting in")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            } else {
                VStack(spacing: 2) {
                    Text("\(engine.bpm)")
                        .font(.pocketMono(.largeTitle))
                        .foregroundStyle(PocketColor.textPrimary)
                        .contentTransition(.numericText())
                    // Becomes the tempo-change warning while one is showing (ADR 0131). The shared
                    // caption also carries ADR 0132's withdrawal word, which never applies on this
                    // screen. Its own view so the per-tick read doesn't re-render the drill surface.
                    RunTempoCaption(engine: engine, fallback: liveTempoCaption)
                }
            }
            ExerciseTemplateSurface(engine: engine, exercise: exercise, labelMode: labelMode)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Setup (stopped)

    /// Edit the exercise's **meter** from the run setup (ADR 0052) — a compact nav-bar control shown
    /// only while stopped. Drives the click's accents + count-in; committed on Start, so leaving
    /// discards it.
    ///
    /// A sheet rather than a popup menu, sharing `OptionListSection` with the metronome's own settings
    /// so the two surfaces that choose a time signature read identically. In a menu these labels
    /// truncated — "12/8 · Slow blues · doo-wop (in 4)" is not a menu-sized string, and the musical
    /// context is the half that tells you which meter you want.
    private var signaturePicker: some View {
        Button { showingSignaturePicker = true } label: {
            Text(signature.name)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .accessibilityLabel("Time signature: \(signature.name)")
        .sheet(isPresented: $showingSignaturePicker) {
            MeterPickerSheet(signature: $signature)
        }
    }

    /// The collapsible **Practice Settings** panel (V1 feedback): the three tempos + the nested
    /// Steps granularity behind one disclosure header, so the setup reads as just the title,
    /// a summary, and the staircase by default. The tempo edits still live in this view's state.
    private var practiceSettings: some View {
        PracticeSettingsPanel(
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
            stepsExpanded: $showSteps, warmupSteps: $steps, reachSteps: $reachSteps,
            backoffSteps: $backoffSteps, dwell: $dwell, dwellCaption: dwellCaption,
            warmupStepBPM: stepBPM,
            hasReach: hasReach, tint: PocketColor.practice, onToggle: { haptic(.light) })
    }

    /// The dwell row's caption — each interval is `automatorDefaultBars` bars at command, so N
    /// intervals ≈ N×that many bars (ADR 0078). Reads the **effective** dwell off `routine`, not the
    /// `dwell` edit state, so inside a generated session it describes the ramp fitted to the block
    /// rather than the stored recipe (ADR 0129) — the caption can't claim a hold the run won't play.
    private var dwellCaption: String {
        "≈ \(routine.dwellIntervals * StandaloneMetronomeEngine.automatorDefaultBars) bars"
    }

    /// The "Edit shape" action handed to the template preview cards (ADR 0077) — opens the
    /// per-template content editor that used to live on the ⓘ sheet, now surfaced from the board's own
    /// header. `nil` in a routine (an exercise is tempo-only) or for a template with no bespoke editor,
    /// so no edit affordance renders there.
    private var editShapeAction: (() -> Void)? {
        guard routineContext == nil, exercise.template.bespokeEditor != nil else { return nil }
        // Editing = authoring (ADR 0112): a free player may reach this screen to *run* a free-taste
        // preset, but editing its shape needs Pro — so gate on `canAuthor`, not `canRun`.
        return {
            if AccessPolicy.canAuthor(exercise.template, isPro: isPro) {
                showingShape = true
                haptic(.light)
            } else {
                presentPaywall(.proExercise)
            }
        }
    }

    /// Persist the tuning without starting a run (ADR 0057) — shown only while the setup differs
    /// from what's stored. A subtle filled capsule, distinct from the filled Start pill below.
    /// Leaving still discards *unsaved* edits.
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
        .accessibilityLabel("Save changes to this exercise")
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // The bottom transport lives in `ExerciseRunView+Transport.swift` — this file is at the
    // 400-line cap CI's `--strict` lint enforces.
}

#Preview("Exercise run") {
    NavigationStack {
        ExerciseRunView(exercise: Exercise(name: "Alternating picking",
                                           currentTempo: 70, commandTempo: 96))
    }
    .preferredColorScheme(.dark)
}
