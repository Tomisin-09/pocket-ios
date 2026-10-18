import SwiftUI

/// **Edit loop › Works on & tags** (ADR 0258): which skills the loop works on (ADR 0216 D6), and its
/// tags (ADR 0034), on one screen because a recognised tag puts a skill in Works on (ADR 0074) — the
/// two read as one subject, as they did side by side on the sheet.
///
/// It edits the sheet's **draft** through bindings: an edit shows here and on the sheet's row before
/// Done, and Cancel takes it away. The skill picker is presented from this screen's own `Form`
/// (ADR 0258 D3) and writes back into the draft when it closes. Rows are built in functions rather than
/// inline in a `Section`: a modifier chain inline in a `Section` builder in a body this size once
/// segfaulted the routine editor.
struct LoopSkillsScreen: View {
    @Binding var skillIDs: [String]
    @Binding var tags: [String]
    /// Tags already used elsewhere in the library, to suggest against (ADR 0034).
    let tagPool: [String]
    let vocabulary: SkillVocabulary

    @State private var newTag = ""
    @State private var editingSkills = false
    @State private var skillOffered: [String] = []
    @State private var skillKept: Set<String> = []

    var body: some View {
        Form {
            worksOnSection
            tagsSection
        }
        .navigationTitle("Works on & tags")
        .navigationBarTitleDisplayMode(.inline)
        // Only the stated skills are offered: a tag's are the tag's.
        .sheet(isPresented: $editingSkills, onDismiss: applyPickedSkills) {
            SkillPickerSheet(offeredSkillIDs: $skillOffered, keptSkillIDs: $skillKept, title: "Works on")
        }
    }

    // MARK: - Works on

    /// The skills the player **stated**, then the ones a recognised bucket tag carries (ADR 0074) —
    /// still read, never migrated, and captioned so the two can be told apart.
    private var worksOnSection: some View {
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
        let tagged = Self.taggedSkills(tags: tags, stated: stated)
        if stated.isEmpty && tagged.isEmpty { emptyWorksOnLine }
        ForEach(stated, id: \.self) { skillID in
            skillRow(skillID, caption: nil)
        }
        ForEach(tagged, id: \.skillID) { entry in
            skillRow(entry.skillID, caption: "From your tag \(entry.template.displayName)")
        }
        editSkillsButton(isEmpty: stated.isEmpty)
    }

    /// The skills `tags` carry that weren't stated already — the sheet's row counts the same ones.
    static func taggedSkills(tags: [String], stated: [String])
        -> [(skillID: String, template: ExerciseTemplate)] {
        SkillAssociation.tagSkills(forTags: tags).filter { !stated.contains($0.skillID) }
    }

    /// Coloured the way the other add rows are (*Add a link*, `ReferencesSection`): a `foregroundStyle`
    /// on the label. A `.tint` on the button coloured the title but left the symbol in the system blue a
    /// bare `Button` in a `Form` falls back to.
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

    private func beginEditingSkills() {
        let stated = vocabulary.resolvable(skillIDs)
        skillOffered = stated
        skillKept = Set(stated)
        editingSkills = true
    }

    /// Back into the draft — written to the loop on Done, like every other field.
    private func applyPickedSkills() {
        skillIDs = SkillAssociation.catalogueOrdered(skillKept)
    }

    // MARK: - Tags

    private var tagsSection: some View {
        Section("Tags") {
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag, style: .selected) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            // The ✨ skill-bucket chips that used to sit here are gone (ADR 0216 D6): Works on above
            // says what a loop is for directly. A tag that spells a kind of drill still counts
            // (ADR 0074) — it just isn't the way in any more.
            HStack {
                TextField("Add a tag", text: $newTag)
                    .submitLabel(.done)
                    .onSubmit(addTag)
                Button("Add", action: addTag)
                    .disabled(Labels.canonical(newTag) == nil)
            }
            if !tagSuggestions.isEmpty {
                tagSuggestionChips
            }
        }
    }

    /// Tappable chips of tags used on other loops — tap to add; horizontally scrolling since long.
    private var tagSuggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tagSuggestions, id: \.self) { suggestion in
                    TagChip(text: suggestion, style: .suggestion) {
                        tags = Labels.adding(suggestion, to: tags)
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    /// Distinct, normalised tags used across every loop in the library, excluding those already on
    /// this loop. `Labels.suggestions` does the distinct/normalise/exclude/sort (shared, ADR 0034).
    private var tagSuggestions: [String] {
        Labels.suggestions(from: tagPool, excluding: tags)
    }

    /// Canonicalise and de-dup case-insensitively through the shared normaliser (ADR 0034,
    /// reusing ADR 0033's machinery) so the tag set never fragments into needs-work / Needs-work.
    private func addTag() {
        tags = Labels.adding(newTag, to: tags)
        newTag = ""
    }
}
