import SwiftData
import SwiftUI

/// Home's **Jump back in** card (ADR 0193): which unit it offers, what it draws, and where a tap
/// goes. Split out of `HomeView` to keep that file under the 400-line cap, and split *here* rather
/// than into `HomeView+Cards` because the card is the one thing on Home whose subject the player
/// chooses.
///
/// `Routine.lastPracticed` and `Exercise.lastPracticed` were both already written on every run and
/// read by nothing on this screen — Home consulted songs alone. So this reads three fields where it
/// read one and **adds none**, which is what makes it cheap under ADR 0189's criteria.
extension HomeView {

    /// The unit the card is offering, with its model attached. `nil` when nothing anywhere has been
    /// practised — the state in which the card has always hidden.
    enum ResumeTarget {
        case song(Song)
        case routine(Routine)
        case exercise(Exercise)
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
        switch HomeFeed.resumeKind(preference: jumpBackIn,
                                   songPracticedAt: song?.lastPracticed,
                                   routinePracticedAt: routine?.lastPracticed,
                                   exercisePracticedAt: exercise?.lastPracticed) {
        case .song: return song.map(ResumeTarget.song)
        case .routine: return routine.map(ResumeTarget.routine)
        case .exercise: return exercise.map(ResumeTarget.exercise)
        case nil: return nil
        }
    }

    /// The card, its Pro gate, its destination and the hold menu that changes what it offers.
    ///
    /// **Gated with the nav strips (ADR 0144 D4)** in all three shapes: each is a *second* door into
    /// a surface the section strips already lock, and a lapsed player who dismissed the launch wall
    /// would otherwise walk straight through it. An exercise takes the `.practice` gate rather than
    /// one of its own, because the door it duplicates is the Practice strip.
    ///
    /// **The hold is ADR 0163's grammar** — the setting put where you are using it, with the
    /// Settings row kept as the findable route. Both surfaces write the same key, so there is no
    /// second copy of the four labels to drift.
    @ViewBuilder
    func resumeCard(_ target: ResumeTarget) -> some View {
        Group {
            switch target {
            case .song(let song):
                proGated(.song) {
                    WaveformPracticeView(song: song, context: context)
                } label: {
                    JumpBackInCard(content: Self.content(song), locked: !isPro)
                }
            case .routine(let routine):
                proGated(.routine) {
                    RoutineDetailView(container: context.container, existing: routine)
                } label: {
                    JumpBackInCard(content: Self.content(routine), locked: !isPro)
                }
            case .exercise(let exercise):
                proGated(.practice) {
                    // Through `ExerciseRunScreen`, never `ExerciseRunView` — it is the one place
                    // that decides which run screen a drill gets, so a freeform block gets its own
                    // (ADR 0136).
                    ExerciseRunScreen(exercise: exercise)
                } label: {
                    JumpBackInCard(content: Self.content(exercise), locked: !isPro)
                }
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
        // The same count `RecentRoutineCard` shows — playable blocks, rests excluded — so the two
        // routine surfaces on one screen cannot state different sizes for one routine.
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
}
