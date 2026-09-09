import SwiftData
import SwiftUI

/// The Exercises library's preview, split out when the folder axis (ADR 0210) took the view itself
/// to the 400-line cap — the same move `ChordPickerSheetPreviews` and `FretboardDrillEditorPreviews`
/// already make. A preview is the one part of a screen no build of the app ever runs, so it is the
/// cheapest thing to move out and the least missed.

#Preview("Exercises — with units") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self, PracticeRun.self, Routine.self,
                                        PracticeFolder.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let picking = Exercise(name: "Alternating picking",
                           currentTempo: 70, commandTempo: 96, template: .picking)
    picking.folders = ["Technique", "Grade 2"]
    container.mainContext.insert(picking)
    let spider = Exercise(name: "Spider", currentTempo: 60, template: .warmup)
    spider.folders = ["Beginner/Warm-ups"]
    container.mainContext.insert(spider)
    container.mainContext.insert(Exercise(name: "Down Up Down", currentTempo: 80,
                                          template: .strumming))
    // A bass exercise trips the progressive-disclosure instrument filter (ADR 0116 S4).
    container.mainContext.insert(Exercise(name: "E minor pentatonic", currentTempo: 60,
                                          template: .scales, instrument: .bass))
    // An empty folder — the marker row (ADR 0210 D4), and the one thing derived paths cannot show.
    container.mainContext.insert(PracticeFolder(path: "Grade 3"))
    return NavigationStack { ExerciseLibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
