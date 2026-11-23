import SwiftData
import SwiftUI

/// What the shape sheet shows **in place of an editor** when an exercise's content was written by a newer
/// version of Red Moon and this one can't read it (ADR 0313 D4, `Exercise.hasUnreadableContent`). An
/// archive restored into an older build, or a shared routine opened on one, is how that happens. The run
/// still plays, as a click; the point of this is that the editor's default is never shown, so Done can't
/// be mistaken for saving it, and the sheet writes nothing.
struct NewerVersionNotice: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Made in a newer version of Red Moon")
                    .font(.futura(.headline, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text("This version can't read its shape, so the exercise runs with the click alone. "
                     + "Update Red Moon to see the shape and change it. Nothing here will touch it.")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("shape.newerVersion")
        }
    }
}

#Preview("Exercise shape — strumming") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let exercise = Exercise(name: "Folk strum", currentTempo: 70, commandTempo: 96,
                            template: .strumming, tags: ["rhythm", "strumming"])
    exercise.setStrumPattern(.folk)
    container.mainContext.insert(exercise)
    return ExerciseShapeSheet(exercise: exercise)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("Exercise shape — made in a newer version") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    // A kind no build has yet. A Triads run was this preview's example until this build learned to read one.
    let exercise = Exercise(name: "Sevenths in C", currentTempo: 70, commandTempo: 96, template: .arpeggios,
                            templatePayload: Data(#"{"kind":"fourNoteShapes","fourNoteShapes":{"version":1}}"#.utf8))
    container.mainContext.insert(exercise)
    return ExerciseShapeSheet(exercise: exercise)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
