import SwiftData
import SwiftUI

extension RoutineDetailView {
    /// Build a **provisional generated session** for review (V2 planner Slices 1 & 3): materialise the
    /// pure generated blocks into a private sandbox (autosave off) so nothing persists until the user
    /// Saves or Starts. Opens read-only on the block list with the dated default name; backing out
    /// without committing discards the sandbox (nothing lands in the library). Fetches exercises,
    /// loops and songs so both a goal-less Quick session (Slice 1, exercise-only) and a goal session
    /// (Slice 3, which can surface loop/song candidates via Path B) resolve their blocks.
    init(container: ModelContainer, generatedSession blocks: [SessionBlock], defaultName: String,
         targetMinutes: Int? = nil) {
        self.init(container: container, targetMinutes: targetMinutes) { context in
            let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
            let loops = (try? context.fetch(FetchDescriptor<Loop>())) ?? []
            let songs = (try? context.fetch(FetchDescriptor<Song>())) ?? []
            return PracticePlanner.materialise(blocks, name: defaultName, exercises: exercises,
                                               loops: loops, songs: songs, into: context)
        }
    }
}
