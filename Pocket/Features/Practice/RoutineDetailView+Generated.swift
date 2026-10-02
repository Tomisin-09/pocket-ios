import SwiftData
import SwiftUI

extension RoutineDetailView {
    /// Build a **provisional generated session** for review (V2 planner Slices 1 & 3): materialise the
    /// pure generated blocks into a private sandbox (autosave off) so nothing persists until the user
    /// Saves or Starts. Opens read-only on the block list with the dated default name; backing out
    /// without committing discards the sandbox (nothing is written). Fetches exercises, loops and
    /// songs so both a goal-less Quick session (Slice 1, exercise-only) and a goal session (Slice 3,
    /// which can surface loop/song candidates via Path B) resolve their blocks.
    ///
    /// `startsAs` has no default, so each caller says what Start does with its session (ADR 0243 D1):
    /// the planner's two pass `.temporary`, the song side passes `.saved`.
    init(container: ModelContainer, generatedSession blocks: [SessionBlock], defaultName: String,
         targetMinutes: Int? = nil, startsAs: ProvisionalStart) {
        self.init(container: container, targetMinutes: targetMinutes, startsAs: startsAs) { context in
            let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
            let loops = (try? context.fetch(FetchDescriptor<Loop>())) ?? []
            let songs = (try? context.fetch(FetchDescriptor<Song>())) ?? []
            return PracticePlanner.materialise(blocks, name: defaultName, exercises: exercises,
                                               loops: loops, songs: songs, into: context)
        }
    }
}
