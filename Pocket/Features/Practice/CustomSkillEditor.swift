import SwiftData
import SwiftUI

/// Make or edit a **skill of the player's own** (ADR 0216 D7): a name, and what it is — the text
/// behind its ⓘ. Presented through a `StableRef` keyed on the row's `uid` when editing, never
/// `.sheet(item:)` on the model, which self-dismisses (ADR 0090).
///
/// The name is held to one rule, `CustomSkill.nameProblem`: not empty, and not the name of another
/// skill — the player's own or the catalogue's — whatever its case or spacing.
struct CustomSkillEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var customSkills: [CustomSkill]

    /// The skill being edited, or `nil` to make a new one.
    let existing: CustomSkill?
    /// Called with a **new** skill's id once it is saved, so the picker that asked for it can keep it
    /// straight away rather than making the player find and tap it.
    let onCreate: (String) -> Void

    @State private var name: String
    @State private var info: String

    init(existing: CustomSkill?, initialName: String = "", onCreate: @escaping (String) -> Void = { _ in }) {
        self.existing = existing
        self.onCreate = onCreate
        _name = State(initialValue: existing?.name ?? initialName)
        _info = State(initialValue: existing?.info ?? "")
    }

    /// Why the name can't be saved, or `nil`. The skill being renamed doesn't clash with itself.
    private var problem: String? {
        let taken = customSkills.filter { $0.uid != existing?.uid }.map(\.name) + TechniqueTaxonomy.all.map(\.name)
        return CustomSkill.nameProblem(name, takenNames: taken)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    nameField
                } header: {
                    Text("Name")
                } footer: {
                    nameFooter
                }
                Section {
                    infoField
                } header: {
                    Text("What it is")
                } footer: {
                    Text("Shown behind the skill\u{2019}s \u{24D8}. Optional.")
                        .font(.futura(.caption))
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "New skill" : "Edit skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(PocketColor.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.futura(.body, weight: .bold))
                        .tint(PocketColor.practice)
                        .disabled(problem != nil)
                }
            }
        }
    }

    // The two fields are their own properties rather than modifier chains written inline in their
    // `Section`s: a `lineLimit(3...8)` chain inline in a `Section` builder is the exact shape that
    // segfaulted the routine editor on open while every test stayed green.

    private var nameField: some View {
        TextField("Live looping", text: $name)
            .font(.futura(.body))
            .accessibilityLabel("Skill name")
    }

    /// Only once something is typed: "Give it a name" under a field the player hasn't touched yet
    /// reads as a telling-off.
    @ViewBuilder private var nameFooter: some View {
        if let problem, !CustomSkill.foldedName(name).isEmpty {
            Text(problem).font(.futura(.caption))
        }
    }

    private var infoField: some View {
        TextField("What it is, in your own words", text: $info, axis: .vertical)
            .lineLimit(3...8)
            .font(.futura(.body))
            .accessibilityLabel("What it is")
    }

    private func save() {
        let cleanName = Labels.canonical(name) ?? ""
        let cleanInfo = info.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.name = cleanName
            existing.info = cleanInfo
        } else {
            let skill = CustomSkill(name: cleanName, info: cleanInfo)
            context.insert(skill)
            onCreate(skill.skillID)
        }
        try? context.save()
        haptic(.medium)
        dismiss()
    }
}

extension SkillVocabulary {
    /// The vocabulary a screen's `CustomSkill` query gives it.
    init(_ skills: [CustomSkill]) {
        self.init(custom: Dictionary(skills.map { ($0.skillID, Custom(name: $0.name, info: $0.info)) },
                                     uniquingKeysWith: { first, _ in first }))
    }
}
