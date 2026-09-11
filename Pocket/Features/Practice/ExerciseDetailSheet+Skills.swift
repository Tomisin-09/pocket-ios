import SwiftUI

/// The ⓘ sheet's **Works on** section (ADR 0216 D6) — which skills this drill serves, and so which
/// goals can pull it into a session.
///
/// Until this existed the link was invisible from the drill's side: the Template footer said the
/// type *"groups the exercise in your library"* and never that the type is also what decides which
/// goals it answers (ADR 0073 Decision 4). Slice 1 shows the link; the type still decides it.
///
/// Its own file for the reason `+Folders` has one: the sheet sits against the 400-line cap.
extension ExerciseDetailSheet {

    /// Absent for a type that works on nothing by default — Basic, Warm-up and Freeform. A section
    /// with nothing in it and no way to change it would be a dead end to read.
    @ViewBuilder var worksOnSection: some View {
        let skills = SkillAssociation.defaultSkills(for: exercise.template)
        if !skills.isEmpty {
            Section {
                ForEach(skills, id: \.self) { skillID in
                    let name = TechniqueTaxonomy.info(skillID)?.name ?? skillID
                    HStack(spacing: 8) {
                        Text(name).foregroundStyle(PocketColor.textPrimary)
                        Spacer(minLength: 8)
                        InfoPopoverButton(subject: name, info: SkillExplainer.text(for: skillID))
                    }
                }
            } header: {
                Text("Works on")
            } footer: {
                Text("Set by its type, \(exercise.template.displayName). A goal on any of these skills "
                     + "can bring this drill into a session.")
            }
        }
    }
}
