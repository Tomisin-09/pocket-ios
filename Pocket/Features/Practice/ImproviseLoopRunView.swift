import SwiftUI

/// An **improvise block** inside a routine (ADR 0135 Slice 2) — the routine counterpart of
/// `LoopRunView` for a loop whose block mode is `.improvise`. It embeds the shared `ImproviseView`
/// (the loop as a backing track, continuous playback at one live tempo, Journal capture) and adds
/// only the routine chrome: the session **progress strip**, **skip**, **exit** (via
/// `routineSessionChrome`), and the block's planned length (ADR 0141) with **Done** beside it in the
/// bottom bar (ADR 0271).
///
/// **Manual advance, no completion screen.** A jam has nothing to grade or promote, so — exactly like
/// an ear block (ADR 0104) and unlike an exercise or loop-trainer block — it never shows a
/// `RoutineBlockDoneView`; `RoutinePlayerView.finishedBlock` skips it for every ramp-less stage. The
/// standalone surface is `ImproviseSheet`; this exists only for the routine player, so
/// `routineContext` is expected to be present.
///
/// **The length is a budget, not a buzzer** (ADR 0141 L2). The block ends when its allotted minutes
/// are up — but at the next loop-region boundary, never mid-phrase, and Done is live throughout. A
/// block that declined the fit (ADR 0130) arrives with no planned minutes and runs open-ended, which
/// is ADR 0135 B3's original behaviour kept as a choice.
struct ImproviseLoopRunView: View {
    let loop: Loop
    var routineContext: RoutineRunContext?
    @Environment(\.modelContext) private var modelContext
    @State private var player: ContinuousLoopPlayer
    /// When this block began (ADR 0117). An improvise block has no Start — the bed plays from
    /// arrival — so the clock starts on appearance rather than on a transport action.
    @State private var startedAt: Date?
    /// Takes are on **inside the routine** here (ADR 0069 amendment): an improvise block is
    /// open-ended by construction, so the take is its only record. Ramped blocks stay gated.
    @State private var recorder = RecordingController()

    init(loop: Loop, routineContext: RoutineRunContext? = nil) {
        self.loop = loop
        self.routineContext = routineContext
        _player = State(initialValue: .improvising(over: loop))
    }

    var body: some View {
        ImproviseView(loop: loop, player: player, recorder: recorder,
                      routineContext: routineContext)
            .navigationTitle(loop.name.isEmpty ? LoopRunMode.improvise.label : loop.name)
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

    /// Log the block as a completed unit-run (ADR 0117 / 0135 B3b). **Done is a genuine completion
    /// here**, not a hand-stop: a jam has no ramp to run its course, so the player deciding they're
    /// finished *is* the end of the run — and so is the block reaching its planned length. Skip and
    /// exit bypass this and log nothing, exactly as they do for an exercise.
    ///
    /// Logged as `.improvise` rather than `.loop`: the same material doing a different job, so it
    /// earns minutes and days without muddying the loop's tempo trajectory. **No tempo** is
    /// recorded — a jam isn't practised *at* a tempo you own, and the live percent is a comfort
    /// setting rather than an achievement.
    private func logCompletedRun() {
        guard let startedAt else { return }
        self.startedAt = nil
        PracticeLogWriter.log(kind: .improvise,
                              startedAt: startedAt,
                              unitUID: loop.uid,
                              routineUID: routineContext?.routineUID,
                              songSourceID: loop.song?.sourceID,
                              unitLabel: loop.name,
                              into: modelContext)
    }

    /// The block's **Done** (or **Finish** on the last block), in the bottom bar beside the time left
    /// (ADR 0271) — quiet, because a jam has nothing to grade. `nil` without a routine,
    /// which this screen is never shown outside of.
    private var done: BlockDone? {
        routineContext.map { BlockDone(title: $0.finishTitle, accessibilityLabel: "Done with this improvise block") }
    }

    /// The one completion seam, shared by the Done button and the block running its length — so a
    /// block that timed out logs and advances exactly like one finished by hand.
    private func finish() {
        // Explicit rather than relying on `ImproviseView`'s teardown to catch it, matching
        // `FreeformRunView.finish()` — and before the log, since advancing tears this screen down.
        recorder.finishIfRecording(owner: .loop(loop, .improvise), context: modelContext)
        logCompletedRun()   // before advancing — advancing tears this screen down
        routineContext?.onFinished()
    }
}

#Preview("Improvise block") {
    let song = Song.sample()
    let loop = Loop(name: "Outro vamp", start: 0.72, end: 0.88, speed: 1.0, repeats: 4)
    loop.song = song
    loop.isBackingTrack = true
    return NavigationStack {
        ImproviseLoopRunView(loop: loop,
                             routineContext: RoutineRunContext(
                                stageIndex: 1, stageCount: 4, autoStart: false, canGoBack: true,
                                plannedMinutes: 10,
                                onBack: {}, onSkip: {}, onFinished: {}, onExit: {}))
    }
    .preferredColorScheme(.dark)
}
