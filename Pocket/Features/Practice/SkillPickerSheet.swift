import SwiftUI

/// The **full-catalog skill picker** (V2 planner R2): a searchable, family-grouped list of every
/// `TechniqueTaxonomy` skill, so a goal isn't limited to the skills its template seeded. Tapping a
/// skill adds it to the goal (and to the editor's trimmable list); tapping a kept skill drops it.
/// No free-text — search only narrows the fixed catalog (an orphan skill schedules nothing,
/// ADR 0015). Binds straight to the `GoalEditorView` state it mutates.
struct SkillPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The editor's ordered display list — a newly picked skill is appended so it shows as a
    /// trimmable row back in the form.
    @Binding var offeredSkillIDs: [String]
    /// The kept subset that actually drives the goal.
    @Binding var keptSkillIDs: Set<String>

    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                let groups = SkillCatalog.search(query)
                if groups.isEmpty {
                    Text("No skills match “\(query)”.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .listRowBackground(PocketColor.background)
                } else {
                    ForEach(groups, id: \.family) { group in
                        Section(group.family.label) {
                            ForEach(group.skills, id: \.id) { skill in
                                skillRow(skill)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search skills")
            .navigationTitle("Add skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: .bold))
                        .tint(PocketColor.practice)
                }
            }
        }
    }

    private func skillRow(_ skill: SkillInfo) -> some View {
        let isKept = keptSkillIDs.contains(skill.id)
        return Button { toggle(skill.id) } label: {
            HStack {
                Text(skill.name)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer()
                Image(systemName: isKept ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isKept ? PocketColor.practice : PocketColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(PocketColor.background)
    }

    /// Add a skill (kept + appended to the offered list if new) or drop it (unchecked only — it
    /// stays an offered row so the form still lists it, matching the trim behaviour there).
    private func toggle(_ skillID: String) {
        if keptSkillIDs.contains(skillID) {
            keptSkillIDs.remove(skillID)
        } else {
            keptSkillIDs.insert(skillID)
            if !offeredSkillIDs.contains(skillID) { offeredSkillIDs.append(skillID) }
        }
        haptic(.light)
    }
}
