import Foundation
import SwiftData

/// Builds a **provisional practice routine for one song** from the ADR-0111 repertoire edge — the
/// pure producer behind "Build a routine for this song". It emits planner `SessionBlock`s (not a
/// persisted `Routine`), so the existing generated-session review flow is reused wholesale:
/// `RoutineDetailView(generatedSession:)` materialises the blocks into a sandbox via
/// `PracticePlanner.materialise`, and the routine only persists when the player taps **Save** —
/// Cancel/back leaves no orphan. The V2 planner (ADR 0064) is a smarter producer of the same blocks;
/// this is the direct-edge one, exactly the "planner becomes a producer of these edges" framing.
///
/// **Shape** — the natural *drills → sections → performance* arc: the song's **linked exercises**
/// (ADR 0111) as focused technique blocks, then its **loops** (the passages already isolated on the
/// waveform) as focused blocks, then a **play-through** of the whole song to put it together. Pure
/// and SwiftData-**reading**-only (no mutation, no context), so it's unit-tested per AGENTS.md; the
/// player reorders/edits freely in the review screen before saving.
enum SongRoutineBuilder {

    /// Per-block practice budget for the generated focused blocks (minutes). A display/estimate hint
    /// only — the real per-block time is driven by each unit's ramp; `RoutineDetailView` lets the
    /// player retune it. Reuses the routine model's default so the number reads consistently.
    static let focusedMinutes = RoutineBudget.defaultFocusedMinutes

    /// Whether a *meaningful* routine can be built: the song has at least one linked exercise **or**
    /// one loop. With neither, the only block would be a lone play-through (i.e. just playing the
    /// song), so the entry point disables rather than generate an empty-feeling routine.
    static func canBuild(for song: Song) -> Bool {
        !song.linkedExercises.isEmpty || !song.loops.isEmpty
    }

    /// The provisional session blocks for `song`, in drills → sections → play-through order.
    /// Exercises are ordered by name and loops by start (`Song.loopsByStart`) for a deterministic,
    /// readable layout. Every exercise/loop is a `.focus` block; the song trails as a `.play` block.
    /// Unit refs match what `PracticePlanner.materialise` resolves against — exercises/loops by their
    /// business `uid`, the song by `PlannerID.uid(from:)` on its `sourceID`.
    static func sessionBlocks(for song: Song) -> [SessionBlock] {
        var blocks: [SessionBlock] = []

        let exercises = song.linkedExercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        for exercise in exercises {
            blocks.append(.focus(PlannerUnitRef(exercise.uid, .exercise),
                                 minutes: focusedMinutes, microRestEvery: nil, mode: .trainer))
        }
        for loop in song.loopsByStart {
            blocks.append(.focus(PlannerUnitRef(loop.uid, .loop),
                                 minutes: focusedMinutes, microRestEvery: nil, mode: .trainer))
        }
        blocks.append(.play(PlannerUnitRef(PlannerID.uid(from: song.sourceID), .song),
                            minutes: playMinutes(for: song), mode: .trainer))
        return blocks
    }

    /// A friendly default name for the generated routine — de-duplicated later by the review screen's
    /// `QuickSessionNaming`, so a repeat build won't collide.
    static func defaultName(for song: Song) -> String {
        song.title.isEmpty ? "Song practice" : "\(song.title) practice"
    }

    /// The play-through block's minutes — the song's length rounded up, at least 1.
    private static func playMinutes(for song: Song) -> Int {
        max(1, Int((song.duration / 60).rounded(.up)))
    }
}
