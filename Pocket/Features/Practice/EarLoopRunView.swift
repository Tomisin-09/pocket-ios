import SwiftUI

/// An **ear-training loop block** inside a routine (ADR 0104 Slice 2). The routine counterpart of
/// `LoopRunView` for a loop whose block mode is `.ear`: it embeds the shared `EarTrainingView`
/// (continuous playback + hum/sing + note capture) and adds only the routine chrome — the session
/// **progress strip**, **skip**, **exit** (via `routineSessionChrome`) — plus the block's bottom bar,
/// where **Done** advances to the next block (ADR 0271, via `rampLessBlockLength`).
///
/// **Manual advance, no completion screen.** Ear internalisation has no ramp or natural end, so unlike
/// exercise/loop blocks it never shows a `RoutineBlockDoneView` (mastery/promote) — the player decides
/// when they've internalised it and taps Done (`RoutinePlayerView.finishedBlock` skips the Done screen
/// for `.earLoop`). Standalone ear training uses `EarTrainingSheet` instead; this exists only for the
/// routine player, so `routineContext` is expected to be present.
struct EarLoopRunView: View {
    let loop: Loop
    var routineContext: RoutineRunContext?
    @Environment(\.modelContext) private var modelContext
    @State private var player: ContinuousLoopPlayer
    /// Takes are on in a routine ear block, matching the improvise block (ADR 0069 amendment): the
    /// ramped run screens keep their `routineContext == nil` gate because a take there belongs to a
    /// ramp, but a hummed line is worth hearing back wherever it was hummed.
    @State private var recorder = RecordingController()
    /// When this block began (ADR 0117). An ear block has no Start — the loop plays from arrival — so
    /// the clock starts on appearance rather than on a transport action.
    @State private var startedAt: Date?

    init(loop: Loop, routineContext: RoutineRunContext? = nil) {
        self.loop = loop
        self.routineContext = routineContext
        _player = State(initialValue: ContinuousLoopPlayer(loop: loop))
    }

    var body: some View {
        EarTrainingView(loop: loop, player: player, recorder: recorder,
                        routineContext: routineContext)
            .navigationTitle(loop.name.isEmpty ? LoopRunMode.ear.label : loop.name)
            .navigationBarTitleDisplayMode(.inline)
            .routineSessionChrome(routineContext)
            .onAppear { if startedAt == nil { startedAt = .now }; armIfBlockRecords() }
            .rampLessBlockLength(plannedMinutes: routineContext?.plannedMinutes,
                                 cycleSeconds: { player.cycleSeconds(for: loop) },
                                 isPlaying: { player.isPlaying },
                                 done: done,
                                 onFinish: finish)
    }

    /// Arm the recorder when this block was marked to record (ADR 0180), so the take begins with the
    /// bed rather than waiting on a tap the player has to remember mid-session.
    ///
    /// A ramp-less block never auto-starts, so unlike the ramped screens its on-screen arm ring is
    /// genuinely reachable — which is why recording has always worked here (ADR 0069 amendment §2).
    /// This does not replace that ring: it pre-sets it. The controls render as already armed, and a
    /// player who changes their mind can disarm this one run without touching the routine.
    ///
    /// `armIfPermitted()` never prompts. The prompt happened when the block was marked, in the
    /// routine editor.
    func armIfBlockRecords() {
        guard routineContext?.recordsTake == true else { return }
        recorder.armIfPermitted()
    }

    /// Log the block as a completed unit-run (ADR 0117). **Done is a genuine completion here**, not a
    /// hand-stop: an ear block has no ramp to run its course, so the player deciding they've
    /// internalised it *is* the end of the run (ADR 0104). Skip and exit bypass this and log nothing,
    /// exactly as they do for an exercise.
    ///
    /// Logged as `.earLoop` rather than `.loop`: it's the same material doing a different job, so it
    /// counts towards minutes and days without muddying a loop's tempo trajectory. No tempo is
    /// recorded — ear training isn't practised *at* a tempo.
    private func logCompletedRun() {
        guard let startedAt else { return }
        self.startedAt = nil
        PracticeLogWriter.log(kind: .earLoop,
                              startedAt: startedAt,
                              unitUID: loop.uid,
                              routineUID: routineContext?.routineUID,
                              songSourceID: loop.song?.sourceID,
                              unitLabel: loop.name,
                              into: modelContext)
    }

    /// The block's **Done** (or **Finish** on the last block), in the bottom bar beside the time left
    /// (ADR 0271) — quiet, because an ear block has nothing to grade. `nil` without a routine,
    /// which this screen is never shown outside of.
    private var done: BlockDone? {
        routineContext.map { BlockDone(title: $0.finishTitle, accessibilityLabel: "Done with this ear-training block") }
    }

    /// The one completion seam, shared by the Done button and the block running its planned length
    /// (ADR 0141) — so a block that timed out logs and advances exactly like one finished by hand.
    private func finish() {
        // Explicit rather than relying on `EarTrainingView`'s teardown to catch it, matching
        // `ImproviseLoopRunView.finish()` — and before the log, since advancing tears this screen down.
        recorder.finishIfRecording(owner: .loop(loop, .ear), context: modelContext)
        logCompletedRun()   // before advancing — advancing tears this screen down
        routineContext?.onFinished()
    }
}

#Preview("Ear loop block") {
    let song = Song.sample()
    let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.85, repeats: 4)
    loop.song = song
    loop.commandTempo = 0.85
    return NavigationStack {
        EarLoopRunView(loop: loop,
                       routineContext: RoutineRunContext(
                        stageIndex: 1, stageCount: 4, autoStart: false, canGoBack: true,
                        onBack: {}, onSkip: {}, onFinished: {}, onExit: {}))
    }
    .preferredColorScheme(.dark)
}
