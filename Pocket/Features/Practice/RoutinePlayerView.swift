import SwiftData
import SwiftUI

/// The **routine player** (ADR 0066, slice 3 / ADR 0071): a full-screen host that runs a routine's
/// blocks end-to-end. It is deliberately *thin* — each exercise/loop block is the **real**
/// `ExerciseRunView` / `LoopRunView`, injected with a `RoutineRunContext`, so every training aid
/// (fretboard/strum/chord preview, Practice Settings, the ramp staircase, promote, journal) is kept,
/// not re-implemented. The session logic lives in `RoutineSessionPlayer`; this view swaps the run
/// screen per block (`.id(stage.id)` so each starts fresh), runs the between-blocks rest countdown,
/// and shows the finished summary. On natural completion a block lands on a **Done screen** (manual
/// advance, the default — ADR 0071 R4) unless auto-advance is on; a rest counts down.
///
/// Deliberately **judgement-free (ADR 0070)**: it shows what's playing and how far along the session
/// is, and nothing about *how well*. The player is the judge.
struct RoutinePlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// Entitlement (ADR 0112) — read here purely as **defence in depth**. The library row already
    /// refuses to present a routine a free player can't run; this second check means a future entry
    /// point that forgets the gate can't turn the player into a way to run Pro exercises (which embed
    /// the real `ExerciseRunView`, itself gated only at the library row).
    @Environment(\.isPro) private var isPro
    /// The routine being run — held so we can stamp `lastPracticed` when the session starts (the
    /// home hub's "recent routines" rail reads it). The player itself is a pure conductor over stages.
    private let routine: Routine
    @State private var player: RoutineSessionPlayer
    /// The just-finished unit block sitting on its **Done screen** (ADR 0071 R4), or `nil`. Set when a
    /// block completes with manual advance (the default); Continue/Finish commits and advances.
    @State private var doneStage: RoutineStage?

    init(routine: Routine) {
        self.routine = routine
        _player = State(initialValue: RoutineSessionPlayer(routine: routine))
    }

    /// Whether this routine may be played at all under the current entitlement (ADR 0112).
    private var runnable: Bool {
        AccessPolicy.canRunRoutine(
            isPro: isPro,
            isFreeTasteRoutine: AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !runnable {
                    lockedView
                } else if let stage = doneStage {
                    doneView(for: stage)
                } else if player.isFinished {
                    finishedView
                } else if player.state == .resting {
                    restView
                } else if let stage = player.current {
                    stageView(stage)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(PocketColor.background.ignoresSafeArea())
        }
        .onAppear {
            guard runnable else { return }
            player.start()
            markPracticed()
        }
        .onDisappear(perform: player.end)
    }

    /// Stamp the routine as practised *now* — for the home hub's "recent routines" rail. Only when
    /// there's something to play (an empty/all-orphaned routine lands straight on the "Nothing to
    /// play" summary, which isn't a practice). Setting the property dirties the model; save so the
    /// rail reflects it even if the app is backgrounded before the next autosave.
    private func markPracticed() {
        guard !player.stages.isEmpty else { return }
        routine.lastPracticed = .now
        try? modelContext.save()
    }

    /// A block finished on its own. On a **multi-rep** block with reps left, it runs the next rep
    /// straight away — reps are back-to-back, so no Done gate between them (ADR 0076). On the **last**
    /// rep: with manual advance (the default) it lands on the **Done screen** for that unit; with
    /// auto-advance on it moves straight on. Skip bypasses all of this. Only units with a journal
    /// (exercise/loop) show Done — a song has no journal/mastery, so it advances without an empty gate
    /// (and in the default loop mode a song never finishes on its own anyway; a Skip moves it on).
    private func finishedBlock() {
        if player.hasMoreReps {
            player.advance()      // next rep of the same block — the run screen restarts on its new id
        } else if !AppSettings.routineAutoAdvance, let stage = player.current,
                  stage.kind != .earLoop, owner(for: stage) != nil {
            // Ear-training blocks never show a Done screen — there's nothing to grade or promote
            // (ADR 0104 Slice 2); their own Done button is the completion, so advance straight on.
            doneStage = stage
        } else {
            player.advance()
        }
    }

    /// Commit the Done screen's optional mastery self-rating, inline note, and opt-in promote in
    /// **one** action (the P3 lesson — no competing "Add entry" button), then advance. Mastery writes
    /// to the unit; the note writes a `JournalWriter` entry (which snapshots the unit's context); an
    /// accepted promote moves an exercise's command up to its reach (ADR 0079 §7). Each may be a no-op
    /// — an unchanged rating, an empty note, and an un-flipped toggle all commit nothing.
    private func commitDone(_ stage: RoutineStage, mastery: Int?, note: String, kind: EntryKind,
                            promoteTo: Int?) {
        if let owner = owner(for: stage) {
            switch owner {
            case .exercise(let exercise):
                exercise.mastery = mastery
                // Promote is exercises-only (ADR 0079 §Scope/§7); the chosen value is already clamped
                // by the Done screen's stepper, and `promoteCommand` also drops a caught-up reach pin.
                if let promoteTo { exercise.promoteCommand(to: promoteTo) }
            case .loop(let loop): loop.mastery = mastery
            }
            _ = JournalWriter.add(to: owner, text: note, kind: kind, into: modelContext)
            try? modelContext.save()
        }
        doneStage = nil
        haptic(.light)
        player.advance()
    }

    @ViewBuilder
    private func doneView(for stage: RoutineStage) -> some View {
        RoutineBlockDoneView(title: stage.title,
                             initialMastery: mastery(for: stage),
                             promote: promoteConfig(for: stage),
                             isLast: player.upNext == nil,
                             upNext: upNextDescriptor()) { mastery, note, kind, promoteTo in
            commitDone(stage, mastery: mastery, note: note, kind: kind, promoteTo: promoteTo)
        }
        // The Done screen sits outside the per-block session chrome, so give it its own way out —
        // Continue advances, but a player mid-routine needs to be able to leave from here too.
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                }
                .tint(PocketColor.textSecondary)
                .accessibilityLabel("Exit routine")
            }
        }
    }

    /// The promote offer for the Done screen (ADR 0079 §7), or `nil` for no row — only for an
    /// **exercise** unit whose (ceiling-clamped) reach sits above command (nothing to promote
    /// otherwise, and loops keep their own promote behaviour, ADR 0079 §Scope). The target defaults to
    /// the reach and is editable from just above command up to the BPM ceiling.
    private func promoteConfig(for stage: RoutineStage) -> RoutineBlockDoneView.PromoteConfig? {
        let ceiling = StandaloneMetronomeEngine.bpmRange.upperBound
        guard let exercise = stage.exercise,
              PromoteOffer.canPromote(reach: exercise.reachTempo, command: exercise.command,
                                      ceiling: ceiling)
        else { return nil }
        return .init(defaultTarget: PromoteOffer.promotedCommand(reach: exercise.reachTempo,
                                                                 ceiling: ceiling),
                     minValue: exercise.command + 1, maxValue: ceiling)
    }

    /// Build the "Up next" descriptor from the next **unit** stage (rests skipped), or `nil` when only
    /// rests / nothing remain. Keeps `RoutineBlockDoneView` SwiftData-free.
    private func upNextDescriptor() -> RoutineBlockDoneView.UpNext? {
        guard let next = player.nextUnitStage(after: player.currentIndex) else { return nil }
        return RoutineBlockDoneView.UpNext(title: next.title,
                                           detail: detailLine(for: next),
                                           symbol: symbol(for: next))
    }

    /// The upcoming unit's supporting line — its command→reach (exercise), song (loop), or artist
    /// (song). Mirrors `RoutineItemRow`.
    private func detailLine(for stage: RoutineStage) -> String? {
        if let exercise = stage.exercise {
            return exercise.commandProgressLabel
        }
        if let loop = stage.loop {
            if stage.kind == .earLoop {
                return loop.song.map { "Ear training · \($0.title)" } ?? "Ear training"
            }
            return loop.song?.title
        }
        if let song = stage.song { return song.artist.isEmpty ? "Play-along" : song.artist }
        return nil
    }

    /// The upcoming unit's type glyph — the exercise's template icon, else a loop/ear/song symbol.
    private func symbol(for stage: RoutineStage) -> String {
        if let exercise = stage.exercise { return exercise.template.iconName }
        if stage.kind == .earLoop { return "ear" }
        if stage.loop != nil { return "repeat" }
        if stage.song != nil { return "music.note" }
        return "questionmark"
    }

    private func owner(for stage: RoutineStage) -> JournalOwner? {
        if let exercise = stage.exercise { return .exercise(exercise) }
        if let loop = stage.loop { return .loop(loop) }
        return nil
    }

    private func mastery(for stage: RoutineStage) -> Int? {
        if let exercise = stage.exercise { return exercise.mastery }
        if let loop = stage.loop { return loop.mastery }
        return nil
    }

    /// The `RoutineRunContext` handed to each run screen — the progress strip's position, whether
    /// this block auto-starts, skip, the natural-completion hook, and exit. Rebuilt each render; all
    /// closures target the stable player, so it's safe for a run screen to wire `onFinished` once.
    private var context: RoutineRunContext {
        RoutineRunContext(stageIndex: player.currentIndex,
                          stageCount: player.stageCount,
                          autoStart: player.shouldAutoStart(at: player.currentIndex),
                          canGoBack: player.canGoBack,
                          repLabel: player.repLabel,
                          onBack: { player.back(); haptic(.light) },
                          onSkip: { player.skip(); haptic(.light) },
                          onFinished: { finishedBlock() },
                          onExit: { dismiss() })
    }

    // MARK: - Unit block → the real run screen

    @ViewBuilder
    private func stageView(_ stage: RoutineStage) -> some View {
        // Key each run screen on the block **and** the current rep, so a multi-rep block restarts the
        // drill from scratch on every rep rather than SwiftUI reusing the finished one (ADR 0076).
        let runID = "\(stage.id.uuidString)-rep\(player.currentRep)"
        switch stage.payload {
        case .exercise(let exercise):
            ExerciseRunView(exercise: exercise, routineContext: context).id(runID)
        case .loop(let loop):
            LoopRunView(loop: loop, routineContext: context).id(runID)
        case .earLoop(let loop):
            EarLoopRunView(loop: loop, routineContext: context).id(runID)
        case .song(let song):
            SongPlayAlongView(song: song, routineContext: context).id(runID)
        case .rest:
            EmptyView()   // rests never reach here — the conductor is in `.resting`
        }
    }

    // MARK: - Rest

    private var restView: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 6) {
                Text("\(player.restRemaining)")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.practice)
                    .contentTransition(.numericText())
                Text("Breathe — next block starts automatically")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let next = player.upNext {
                VStack(spacing: 4) {
                    Text("Up next")
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .textCase(.uppercase)
                    Text(next.title)
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.practiceCircleWash))
            }
            Spacer()
        }
        .padding(24)
        .navigationTitle("Rest")
        .routineSessionChrome(context)
        .keepAwakeDuringPractice()   // hold the screen through the rest (ADR 0050); the block run
                                     // screens have it, but a rest has no child to assert it
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 16) {
            Image(systemName: player.stages.isEmpty ? "questionmark.circle" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(PocketColor.practice)
            Text(player.stages.isEmpty ? "Nothing to play" : "Session complete")
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.textPrimary)
            Text(player.stages.isEmpty
                 ? "This routine has no playable exercises or loops yet."
                 : "Nice work. Find the music in the mistakes.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
            if !practicedTitles.isEmpty { recap }
            Button { dismiss() } label: {
                Label("Done", systemImage: "checkmark").pocketRunButton
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .keepAwakeDuringPractice()   // the summary lingers on screen after the last block (ADR 0050)
    }

    /// A judgement-free recap — just *what* you worked through this session, no scores (ADR 0070).
    private var recap: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("You practised")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .textCase(.uppercase)
            ForEach(Array(practicedTitles.enumerated()), id: \.offset) { _, title in
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(PocketColor.practice)
                    Text(title)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.practiceCircleWash))
    }

    /// The unit blocks (exercises/loops) in this routine, in order — the recap list; rests omitted.
    private var practicedTitles: [String] {
        player.stages.filter { $0.kind != .rest }.map(\.title)
    }
}

extension RoutinePlayerView {
    /// The entitlement backstop a free player should never actually reach (ADR 0112) — a plain
    /// "this is Pro" wall with a way out, rather than a silent dismissal or (worse) an unlocked
    /// session. No paywall is raised from here: the gate that *presents* this screen is the one
    /// that offers the upgrade. Lives in an extension to keep the main view body under the
    /// type-body-length cap.
    var lockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.futura(.largeTitle))
                .foregroundStyle(PocketColor.textSecondary)
            Text("Routines are part of Red Moon Pro")
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .font(.futura(.body))
                .tint(PocketColor.practice)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Routine player") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Routine.self, RoutineItem.self, Exercise.self, Song.self, Loop.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let drill = Exercise(name: "Alternating picking", currentTempo: 70, commandTempo: 96)
    container.mainContext.insert(drill)
    let routine = Routine(name: "Morning warm-up")
    routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                     RoutineItem.rest(order: 1),
                     RoutineItem.item(drill, order: 2)]
    container.mainContext.insert(routine)
    try? container.mainContext.save()
    return RoutinePlayerView(routine: routine)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
