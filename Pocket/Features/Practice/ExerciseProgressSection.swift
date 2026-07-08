import SwiftUI

/// The exercise detail sheet's **Progress** section (V2 planner Slice 1): a self-rated mastery
/// dot picker plus a read-only "last practised" readout. Split out of `ExerciseDetailSheet` to keep
/// that file under the 400-line cap, and standalone (not a `private` member) so it is independently
/// previewable.
///
/// Mastery is the self-assessment the planner reads as *need* (ADR 0070: you set it, the app never
/// measures how well you played). Mirrors the loop editor's dot control exactly.
struct ExerciseProgressSection: View {
    /// The edited mastery (0–5, `nil` = unrated), committed by the host sheet on Done.
    @Binding var mastery: Int?
    /// When the exercise was last practised — read-only, stamped by the run path.
    let lastPracticed: Date?

    var body: some View {
        Section {
            LabeledContent("Mastery") {
                HStack(spacing: 10) {
                    if mastery == nil {
                        Text("Unrated")
                            .font(.futura(.subheadline))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    ForEach(1...5, id: \.self) { value in
                        Circle()
                            .fill(value <= (mastery ?? 0) ? PocketColor.mastery : PocketColor.barDefault)
                            .frame(width: 18, height: 18)
                            .onTapGesture {
                                // Tap sets the value; tapping the lowest filled dot walks it down,
                                // below 1 clears back to unrated — always a deliberate rating.
                                mastery = (mastery == value) ? (value == 1 ? nil : value - 1) : value
                            }
                            .accessibilityLabel("Set mastery to \(value)")
                    }
                }
            }
            if let lastPracticed {
                LabeledContent("Last practised") {
                    Text(lastPracticed.formatted(.relative(presentation: .named)))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        } header: {
            Text("Progress")
        } footer: {
            Text("How cleanly you own this drill — you set it, the app never scores you. The planner "
                 + "resurfaces well-learned drills over time on its own.")
        }
    }
}
