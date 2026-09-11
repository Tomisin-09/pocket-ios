import SwiftData
import SwiftUI

/// The **skill picker** (V2 planner R2; ADR 0216 D6/D7): every `TechniqueTaxonomy` skill, grouped
/// and searchable, and the skills the player made — so a goal, a drill or a loop isn't limited to
/// what it started with. Tapping toggles, the ⓘ explains, and a search the catalogue can't answer
/// offers to **make** the skill, with the player's own words behind its ⓘ.
///
/// Free text is allowed here since ADR 0216 D7 lifted ADR 0015 Decision 7's ban. That ban existed
/// because an orphan skill schedules nothing; the goal editor now shows an orphan and offers the fix.
/// Binds straight to the caller's state.
struct SkillPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomSkill.dateAdded) private var customSkills: [CustomSkill]

    /// The caller's ordered list — a newly picked skill is appended so it shows as a row back there.
    @Binding var offeredSkillIDs: [String]
    /// The kept subset.
    @Binding var keptSkillIDs: Set<String>
    /// The skills the unit works on **by default** — a drill's type's (ADR 0216 D1) — badged, so
    /// dropping one reads as narrowing rather than as losing something unexplained.
    var defaults: Set<String> = []
    /// Whether Done needs a skill kept. True for a typed drill: kept empty stores empty, and empty
    /// means *its type's defaults* — the reset, not "works on nothing".
    var requiresOne = false
    var title = "Add skills"

    @State private var query = ""
    @State private var creating: NewSkillRequest?
    @State private var editing: StableRef<CustomSkill>?
    @State private var deleting: PendingDelete?

    /// A new skill's form, seeded with what was searched for.
    struct NewSkillRequest: Identifiable {
        let id = UUID()
        let name: String
    }

    /// A delete waiting on its confirmation. The words are taken when the swipe happens, so the
    /// dialog never reads a row that its own button has just deleted.
    struct PendingDelete {
        let skill: StableRef<CustomSkill>
        let title: String
        let message: String
    }

    private var vocabulary: SkillVocabulary { SkillVocabulary(customSkills) }
    private var isDoneBlocked: Bool { requiresOne && keptSkillIDs.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                ownSection
                ForEach(SkillCatalog.search(query), id: \.family) { group in
                    Section(group.family.label) {
                        ForEach(group.skills, id: \.id) { skill in
                            skillRow(skill.id, name: skill.name, explanation: SkillExplainer.text(for: skill.id))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search or name a skill")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: .bold))
                        .tint(PocketColor.practice)
                        .disabled(isDoneBlocked)
                }
            }
            .interactiveDismissDisabled(isDoneBlocked)
        }
        .sheet(item: $creating) { request in
            CustomSkillEditor(existing: nil, initialName: request.name) { keep($0) }
        }
        .sheet(item: $editing) { ref in
            CustomSkillEditor(existing: ref.value)
        }
        .confirmationDialog(deleting?.title ?? "", isPresented: isConfirmingDelete,
                            titleVisibility: .visible, presenting: deleting) { pending in
            Button("Delete skill", role: .destructive) { remove(pending.skill.value) }
        } message: { pending in
            Text(pending.message)
        }
    }

    // MARK: - Your own

    /// **Your own** — the skills the player made, and the way to make one. First, so the way to name
    /// something the catalogue lacks is where a player looks when it lacks it.
    @ViewBuilder private var ownSection: some View {
        let own = matchingCustomIDs
        let offer = createOffer
        if !own.isEmpty || offer != nil {
            Section {
                ForEach(own, id: \.self) { skillID in ownRow(skillID) }
                if let offer { createRow(offer) }
            } header: {
                Text("Your own")
            } footer: {
                Text("Skills you make, with your own words behind the \u{24D8}. Swipe one to edit or delete it.")
                    .font(.futura(.caption))
            }
        }
    }

    /// The name a Create row offers: the search, cleaned; `""` for a plain *New skill* when nothing
    /// is typed; `nil` when the search already names a skill, so there is nothing to make.
    private var createOffer: String? {
        guard let typed = Labels.canonical(query) else { return "" }
        let taken = customSkills.map(\.name) + TechniqueTaxonomy.all.map(\.name)
        return CustomSkill.nameProblem(typed, takenNames: taken) == nil ? typed : nil
    }

    private var matchingCustomIDs: [String] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return vocabulary.customIDsByName.filter { skillID in
            needle.isEmpty
                || vocabulary.name(skillID).range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private func createRow(_ name: String) -> some View {
        Button { creating = NewSkillRequest(name: name) } label: {
            Label(name.isEmpty ? "New skill" : "Create \u{201C}\(name)\u{201D}", systemImage: "plus.circle")
                .font(.futura(.body))
                .foregroundStyle(PocketColor.practice)
        }
        .listRowBackground(PocketColor.background)
    }

    private func ownRow(_ skillID: String) -> some View {
        skillRow(skillID, name: vocabulary.name(skillID), explanation: vocabulary.explanation(skillID))
            .swipeActions {
                if let skill = customSkills.first(where: { $0.skillID == skillID }) {
                    Button("Delete", role: .destructive) { confirmDelete(skill) }
                    Button("Edit") { editing = StableRef(value: skill) }
                        .tint(PocketColor.practice)
                }
            }
    }

    // MARK: - Rows

    /// The toggle and the ⓘ are **siblings** (ADR 0216 D5) — a button inside a button's label fires
    /// both, so reading about a skill would also add it.
    private func skillRow(_ skillID: String, name: String, explanation: String) -> some View {
        let isKept = keptSkillIDs.contains(skillID)
        let isDefault = defaults.contains(skillID)
        return HStack(spacing: 4) {
            Button { toggle(skillID) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                        if isDefault {
                            Text("From its type")
                                .font(.futura(.caption))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: isKept ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(isKept ? PocketColor.practice : PocketColor.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            .accessibilityValue(isDefault ? "From its type" : "")
            .accessibilityAddTraits(isKept ? .isSelected : [])
            InfoPopoverButton(subject: name, info: explanation)
        }
        .listRowBackground(PocketColor.background)
    }

    // MARK: - Actions

    /// Keep a skill — appended to the caller's list if new, so it shows as a row back there.
    private func keep(_ skillID: String) {
        keptSkillIDs.insert(skillID)
        if !offeredSkillIDs.contains(skillID) { offeredSkillIDs.append(skillID) }
    }

    /// Add a skill, or drop it (unchecked only — it stays an offered row so the caller still lists
    /// it, matching the trim behaviour there).
    private func toggle(_ skillID: String) {
        if keptSkillIDs.contains(skillID) { keptSkillIDs.remove(skillID) } else { keep(skillID) }
        haptic(.light)
    }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func confirmDelete(_ skill: CustomSkill) {
        let usage = CustomSkillStore.usage(of: skill.skillID, in: context)
        let consequence = "It comes off everything marked with it, and a drill left with none goes "
            + "back to its type\u{2019}s skills."
        deleting = PendingDelete(skill: StableRef(value: skill),
                                 title: "Delete \u{201C}\(skill.name)\u{201D}?",
                                 message: [usage.summary, consequence].compactMap { $0 }.joined(separator: " "))
    }

    /// Delete the skill and take it off everything — the caller's own working copy included, which
    /// the store's sweep can't reach.
    private func remove(_ skill: CustomSkill) {
        let skillID = skill.skillID
        CustomSkillStore.delete(skill, in: context)
        keptSkillIDs.remove(skillID)
        offeredSkillIDs.removeAll { $0 == skillID }
        deleting = nil
        haptic(.medium)
    }
}
