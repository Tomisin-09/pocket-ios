import SwiftData
import SwiftUI

/// Previews for the Progress screen (ADR 0117, Slice 2), kept out of the view file so it stays under
/// the 400-line cap. Three states, because the **empty ones are the design work**: a fresh install
/// meets this screen at zero, and a screen the player navigated to can't hide the way the old derived
/// home card did.
#Preview("Progress — a few weeks in") {
    NavigationStack { PracticeProgressView() }
        .modelContainer(ProgressPreview.container(weeks: 5))
}

#Preview("Progress — first week") {
    NavigationStack { PracticeProgressView() }
        .modelContainer(ProgressPreview.container(weeks: 1))
}

#Preview("Progress — nothing logged yet") {
    NavigationStack { PracticeProgressView() }
        .modelContainer(ProgressPreview.container(weeks: 0))
        .preferredColorScheme(.dark)
}

/// Seeds an in-memory store with a plausible practice history: a handful of drills run most days at
/// slowly climbing tempos, so the week bars, the month ramp and the "new tempos" count all have
/// something real to render.
private enum ProgressPreview {
    @MainActor static func container(weeks: Int) -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: Song.self, Loop.self, Exercise.self, JournalEntry.self, Recording.self, TakeNote.self,
            PracticeRun.self,
            configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let drills = ["Alternate picking", "A minor pentatonic", "Chord changes"]
        let units = drills.map { name -> Exercise in
            let exercise = Exercise(name: name, currentTempo: 76, commandTempo: 88)
            context.insert(exercise)
            return exercise
        }
        guard weeks > 0 else { return container }

        let day = 60.0 * 60 * 24
        // Walk backwards from today so the current week is always partly filled.
        for index in 0..<(weeks * 7) {
            // A rest day roughly every third day, so the week chart and the heatmap both show gaps.
            guard index % 3 != 1 else { continue }
            let start = Date.now.addingTimeInterval(-day * Double(index)).addingTimeInterval(-3600)
            for (offset, unit) in units.enumerated() {
                let climb = (weeks * 7 - index) / 6      // tempo creeps up over the history
                let run = PracticeRun(startedAt: start.addingTimeInterval(Double(offset) * 420),
                                      durationSeconds: Double(360 + offset * 120),
                                      kind: .exercise,
                                      unitUID: unit.uid,
                                      tempoBPM: 76 + climb + offset * 4,
                                      notesPerBeat: 4)
                context.insert(run)
            }
        }
        return container
    }
}
