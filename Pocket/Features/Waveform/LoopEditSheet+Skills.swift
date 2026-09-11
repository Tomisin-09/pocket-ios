import SwiftUI

// The loop editor's **Works on** section (ADR 0216 D6), split out for the 400-line cap like the
// sheet's other field sections.
extension LoopEditSheet {

    /// Which skills this loop serves, and why. Slice 1 reads them from the loop's recognised bucket
    /// tags (ADR 0074) — a tag that happens to spell a kind of drill, which until now was the only
    /// way a loop reached a technique goal and was visible nowhere but the ✨ chips.
    ///
    /// Reads the sheet's **local** `tags`, not the stored loop's, so adding a ✨ chip below shows its
    /// skills here immediately — before Done — and Cancel takes both away together.
    var worksOnSection: some View {
        let skills = SkillAssociation.tagSkills(forTags: tags)
        return Section {
            if skills.isEmpty {
                Text("Nothing yet. Add one of the \u{2728} kinds of drill under Tags \u{2014} Picking, "
                     + "Scales and the rest \u{2014} and goals on those skills can bring this loop into "
                     + "a session.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                ForEach(skills, id: \.skillID) { entry in
                    let name = TechniqueTaxonomy.info(entry.skillID)?.name ?? entry.skillID
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).foregroundStyle(PocketColor.textPrimary)
                            Text("From your tag \(entry.template.displayName)")
                                .font(.futura(.caption))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                        Spacer(minLength: 8)
                        InfoPopoverButton(subject: name, info: SkillExplainer.text(for: entry.skillID))
                    }
                }
            }
        } header: {
            Text("Works on")
        } footer: {
            Text("Any loop with audio can also be run in Train your ear, which works on your ear.")
        }
    }
}
