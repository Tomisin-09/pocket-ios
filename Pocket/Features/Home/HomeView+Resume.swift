import SwiftData
import SwiftUI

/// Home's **Jump back in** card (ADR 0193): which unit it offers, what it draws, and where a tap
/// goes. Split out of `HomeView` to keep that file under the 400-line cap, and split *here* rather
/// than into `HomeView+Cards` because the card is the one thing on Home whose subject the player
/// chooses.
///
/// `Routine.lastPracticed` and `Exercise.lastPracticed` were both already written on every run and
/// read by nothing on this screen — Home consulted songs alone. So this reads three fields where it
/// read one and **adds none**, which is what makes it cheap under ADR 0189's criteria. A loop has no
/// such field; since ADR 0267 its date and mode come from the practice log, which still adds none.
extension HomeView {

    /// The unit the card is offering, with its model attached. `nil` when nothing anywhere has been
    /// practised — the state in which the card has always hidden.
    enum ResumeTarget {
        case song(Song)
        case routine(Routine)
        case exercise(Exercise)
        /// A loop, in the mode it reopens in, and when it was run (ADR 0267).
        case loop(Loop, LoopRunMode, Date)
    }

    /// The newest **loop-mode** rows of the practice log, newest first, at most
    /// `HomeFeed.recentLoopRunLimit` of them (ADR 0267).
    ///
    /// **Filtered on `kindRaw` alone**, a plain `String`: an optional comparison in a `#Predicate`
    /// freezes the main thread (`docs/swiftdata-gotchas.md`), so the `routineUID` test is left to
    /// `HomeFeed.loopResumeCandidates`, in memory. **Bounded**, because Home has refused an unbounded
    /// query over the log twice (`HomeStatsStrip`, `completedSittingCount`). And a live `@Query`, not a
    /// fetch on appear: ear training and improvise log in `.onDisappear`, which can land after Home's
    /// `.onAppear`, and a fetch would then miss the run the player just finished.
    nonisolated static var recentLoopRuns: FetchDescriptor<PracticeRun> {
        let kinds = PracticeRunKind.allCases.filter { $0.loopRunMode != nil }.map(\.rawValue)
        var descriptor = FetchDescriptor<PracticeRun>(
            predicate: #Predicate { kinds.contains($0.kindRaw) },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = HomeFeed.recentLoopRunLimit
        return descriptor
    }

    /// A loop the card can offer: the live model, the mode it reopens in, and when it was run.
    struct ResumableLoop {
        let loop: Loop
        let mode: LoopRunMode
        let date: Date
    }

    /// The newest loop run on its own whose loop still exists and can open in some mode — preferring
    /// the mode it was run in (`LoopModeAccess.mode(preferring:for:)`, the Journal's rule too).
    private var resumableLoop: ResumableLoop? {
        for candidate in HomeFeed.loopResumeCandidates(recentLoopRuns.map(\.record)) {
            guard let loop = loops.first(where: { $0.uid == candidate.loopUID }),
                  let mode = LoopModeAccess.mode(preferring: candidate.mode, for: loop) else { continue }
            return ResumableLoop(loop: loop, mode: mode, date: candidate.startedAt)
        }
        return nil
    }

    /// The player's stated preference, resolved through the one constant both this and
    /// `JumpBackInSection` bind to.
    var jumpBackIn: JumpBackInPreference {
        AppSettings.resolvedJumpBackIn(storedValue: jumpBackInRaw)
    }

    /// The most-recently-practised unit of each kind, put to the pure rule, then resolved back into
    /// a model. Two steps rather than one so the *choosing* stays testable without a store: the kind
    /// is decided by `HomeFeed.resumeKind`, and this only looks the winner up again.
    var resumeTarget: ResumeTarget? {
        let song = HomeFeed.mostRecentlyPracticed(songs, practicedAt: \.lastPracticed)
        let routine = HomeFeed.mostRecentlyPracticed(routines, practicedAt: \.lastPracticed)
        let exercise = HomeFeed.mostRecentlyPracticed(exercises, practicedAt: \.lastPracticed)
        let loop = resumableLoop
        switch HomeFeed.resumeKind(preference: jumpBackIn,
                                   songPracticedAt: song?.lastPracticed,
                                   routinePracticedAt: routine?.lastPracticed,
                                   exercisePracticedAt: exercise?.lastPracticed,
                                   loopPracticedAt: loop?.date) {
        case .song: return song.map(ResumeTarget.song)
        case .routine: return routine.map(ResumeTarget.routine)
        case .exercise: return exercise.map(ResumeTarget.exercise)
        case .loop: return loop.map { ResumeTarget.loop($0.loop, $0.mode, $0.date) }
        case nil: return nil
        }
    }

    /// The card, its destination and the hold menu that changes what it offers.
    ///
    /// **The hold is ADR 0163's grammar** — the setting put where you are using it, with the
    /// Settings row kept as the findable route. Both surfaces write the same key, so there is no
    /// second copy of the labels to drift.
    @ViewBuilder
    func resumeCard(_ target: ResumeTarget) -> some View {
        Group {
            switch target {
            case .song(let song):
                NavigationLink {
                    WaveformPracticeView(song: song, context: context)
                } label: {
                    JumpBackInCard(content: Self.content(song))
                }
            case .routine(let routine):
                NavigationLink {
                    RoutineDetailView(container: context.container, existing: routine)
                } label: {
                    JumpBackInCard(content: Self.content(routine), locked: plan.showsPlanLocks)
                }
                .planLockedValue(plan.showsPlanLocks)
            case .exercise(let exercise):
                NavigationLink {
                    // Through `ExerciseRunScreen`, never `ExerciseRunView` — it is the one place
                    // that decides which run screen a drill gets, so a freeform block gets its own
                    // (ADR 0136).
                    ExerciseRunScreen(exercise: exercise)
                } label: {
                    JumpBackInCard(content: Self.content(exercise), locked: plan.showsPlanLocks)
                }
                .planLockedValue(plan.showsPlanLocks)
            case .loop(let loop, let mode, let date):
                NavigationLink {
                    // The pushed host for the mode, which gates itself (ADR 0256 D3): all three of a
                    // loop's launches are the plan's.
                    LoopModeScreen(loop: loop, mode: mode)
                } label: {
                    JumpBackInCard(content: Self.content(loop, mode: mode, practiced: date),
                                   locked: plan.showsPlanLocks)
                }
                .planLockedValue(plan.showsPlanLocks)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Picker("Jump back in", selection: $jumpBackInRaw) {
                ForEach(JumpBackInPreference.allCases) { option in
                    Text(option.label).tag(option.rawValue)
                }
            }
        }
    }

    // MARK: - What each kind puts on the card

    private static func content(_ song: Song) -> JumpBackInCard.Content {
        JumpBackInCard.Content(title: song.title, subtitle: song.artist,
                               practiced: song.lastPracticed, trailing: .mastery(song.mastery))
    }

    private static func content(_ routine: Routine) -> JumpBackInCard.Content {
        // Playable blocks, rests excluded: what the routine will actually have you play.
        let blocks = routine.orderedItems.filter { $0.kind != .rest && $0.hasResolvableUnit }.count
        return JumpBackInCard.Content(title: routine.name.isEmpty ? "Routine" : routine.name,
                                      subtitle: nil, practiced: routine.lastPracticed,
                                      trailing: .blocks(blocks))
    }

    private static func content(_ exercise: Exercise) -> JumpBackInCard.Content {
        // `commandProgressLabel` is what the Exercises library row already captions a drill with,
        // and it is empty for a freeform block that asks for no click — which the card reads as
        // "nothing to say" rather than printing a blank line.
        JumpBackInCard.Content(title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                               subtitle: exercise.commandProgressLabel,
                               practiced: exercise.lastPracticed,
                               trailing: .mastery(exercise.mastery))
    }

    private static func content(_ loop: Loop, mode: LoopRunMode, practiced: Date) -> JumpBackInCard.Content {
        // The second line says where a tap goes — *Slow Bend · Train your ear* — because one `Loop`
        // value covers three screens (ADR 0267). Improvise draws no mastery: a bed to solo over isn't
        // something you rate yourself on, which is why its run logs no tempo either.
        let subtitle = [loop.song?.title, mode.label].compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " · ")
        return JumpBackInCard.Content(title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                                      subtitle: subtitle, practiced: practiced,
                                      trailing: mode == .improvise ? .none : .mastery(loop.mastery))
    }
}
