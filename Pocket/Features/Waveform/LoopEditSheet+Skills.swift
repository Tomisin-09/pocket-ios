import SwiftUI

// The loop editor's **Works on** section (ADR 0216 D6), split out for the 400-line cap like the
// sheet's other field sections. Rows are built in functions rather than inline in the `Section`: a
// modifier chain inline in a `Section` builder in a body this size once segfaulted the routine editor.
extension LoopEditSheet {

    /// Which skills this loop works on, and why: the ones the player **stated**, then the ones a
    /// recognised bucket tag carries (ADR 0074) — still read, never migrated, and captioned so the
    /// two can be told apart. Reads the sheet's **local** `skillIDs` and `tags`, so an edit shows here
    /// before Done, and Cancel takes it away.
    var worksOnSection: some View {
        Section {
            worksOnRows
        } header: {
            Text("Works on")
        } footer: {
            Text("A skill from a tag goes when the tag does. Any loop with audio can also be run in "
                 + "Train your ear, which works on your ear.")
        }
    }

    @ViewBuilder private var worksOnRows: some View {
        let stated = vocabulary.resolvable(skillIDs)
        let tagged = SkillAssociation.tagSkills(forTags: tags).filter { !stated.contains($0.skillID) }
        if stated.isEmpty && tagged.isEmpty { emptyWorksOnLine }
        ForEach(stated, id: \.self) { skillID in
            skillRow(skillID, caption: nil)
        }
        ForEach(tagged, id: \.skillID) { entry in
            skillRow(entry.skillID, caption: "From your tag \(entry.template.displayName)")
        }
        editSkillsButton(isEmpty: stated.isEmpty)
    }

    /// Coloured the way the sheet's other add rows are (*Add a link*, `ReferencesSection`): a
    /// `foregroundStyle` on the label. A `.tint` on the button coloured the title but left the
    /// symbol in the system blue a bare `Button` in this `Form` falls back to.
    private func editSkillsButton(isEmpty: Bool) -> some View {
        Button(action: beginEditingSkills) {
            Label(isEmpty ? "Add skills" : "Change skills", systemImage: "plus.circle")
                .foregroundStyle(PocketColor.practice)
        }
    }

    private var emptyWorksOnLine: some View {
        Text("Nothing yet. Add a skill, and a goal on it can bring this loop into a session.")
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
    }

    private func skillRow(_ skillID: String, caption: String?) -> some View {
        let name = vocabulary.name(skillID)
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).foregroundStyle(PocketColor.textPrimary)
                if let caption {
                    Text(caption)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            Spacer(minLength: 8)
            InfoPopoverButton(subject: name, info: vocabulary.explanation(skillID))
        }
    }

    /// The picker — presented from the sheet's top level, since a sheet presented from inside the
    /// `Form` would dismiss this one. Only the stated skills are offered: a tag's are the tag's.
    var skillsPicker: some View {
        SkillPickerSheet(offeredSkillIDs: $skillOffered, keptSkillIDs: $skillKept, title: "Works on")
    }

    private func beginEditingSkills() {
        let stated = vocabulary.resolvable(skillIDs)
        skillOffered = stated
        skillKept = Set(stated)
        editingSkills = true
    }

    /// Back into the local copy — written to the loop on Done, like every other field here.
    func applyPickedSkills() {
        skillIDs = SkillAssociation.catalogueOrdered(skillKept)
    }
}
