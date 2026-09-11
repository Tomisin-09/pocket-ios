import SwiftUI

/// The ⓘ sheet's **Works on** section (ADR 0216 D6) — which skills this drill works on, and so which
/// goals can pull it into a session — and the one place those skills are changed.
///
/// The type sets a **default**; the player can narrow it or add to it, and it is the same edit
/// either way (D1). The picker opens with the current skills kept, and whatever is kept when it
/// closes is the list — stored empty if that is exactly the type's own, so the drill goes on
/// following its type.
///
/// Its own file for the reason `+Folders` has one: the sheet sits against the 400-line cap. The rows
/// are built in their own functions rather than inline in the `Section`, because a modifier chain
/// inline in a `Section` builder in this size of body is what once segfaulted the routine editor.
extension ExerciseDetailSheet {

    /// What the drill works on now, as the screen lists it — its stated skills or its type's, less
    /// any id that names nothing (a skill deleted elsewhere).
    var workedOnSkills: [String] {
        vocabulary.resolvable(SkillAssociation.effectiveSkills(template: exercise.template,
                                                               stated: exercise.skillIDs))
    }

    /// Absent for a warm-up only: it works on nothing whatever is stored (ADR 0072). Basic and
    /// Freeform show it, empty until they say — they are exactly the drills that need to.
    @ViewBuilder var worksOnSection: some View {
        if exercise.template != .warmup {
            Section {
                worksOnRows(workedOnSkills)
            } header: {
                Text("Works on")
            } footer: {
                Text(worksOnFooter)
            }
        }
    }

    @ViewBuilder private func worksOnRows(_ skills: [String]) -> some View {
        if skills.isEmpty { emptyWorksOnLine }
        ForEach(skills, id: \.self) { skillID in worksOnRow(skillID) }
        Button(action: beginEditingSkills) {
            Label(skills.isEmpty ? "Add skills" : "Change skills", systemImage: "plus.circle")
        }
        if isSetByPlayer && hasTypeDefaults {
            Button("Use its type’s skills", action: resetSkillsToType)
        }
    }

    private var emptyWorksOnLine: some View {
        Text("Nothing yet. Add a skill, and a goal on it can bring this drill into a session.")
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
    }

    private func worksOnRow(_ skillID: String) -> some View {
        let name = vocabulary.name(skillID)
        return HStack(spacing: 8) {
            Text(name).foregroundStyle(PocketColor.textPrimary)
            Spacer(minLength: 8)
            InfoPopoverButton(subject: name, info: vocabulary.explanation(skillID))
        }
    }

    private var hasTypeDefaults: Bool { !SkillAssociation.defaultSkills(for: exercise.template).isEmpty }

    private var isSetByPlayer: Bool {
        SkillAssociation.isSetByPlayer(template: exercise.template, stated: exercise.skillIDs)
    }

    private var worksOnFooter: String {
        let reach = "A goal on any of these skills can bring this drill into a session."
        guard hasTypeDefaults else { return "What this drill is for. \(reach)" }
        if isSetByPlayer { return "Set by you. \(reach)" }
        return "From its type, \(exercise.template.displayName). Change them to narrow it or add more. \(reach)"
    }

    /// The picker **Change skills** opens — presented from the sheet's top level, like the song and
    /// folder pickers, because a sheet presented from inside the `Form` dismisses this one.
    var skillsPicker: some View {
        SkillPickerSheet(offeredSkillIDs: $skillOffered, keptSkillIDs: $skillKept,
                         defaults: Set(SkillAssociation.defaultSkills(for: exercise.template)),
                         requiresOne: hasTypeDefaults, title: "Works on")
    }

    private func beginEditingSkills() {
        let current = workedOnSkills
        skillOffered = current
        skillKept = Set(current)
        editingSkills = true
    }

    /// Store what the picker closed on (D1). Written straight through, like the song links above,
    /// rather than held for Done — the picker has a Done of its own.
    func commitSkills() {
        let stored = SkillAssociation.storedSkills(kept: skillKept, template: exercise.template)
        guard stored != exercise.skillIDs else { return }
        exercise.skillIDs = stored
        try? modelContext.save()
    }

    private func resetSkillsToType() {
        exercise.skillIDs = []
        try? modelContext.save()
        haptic(.light)
    }
}
