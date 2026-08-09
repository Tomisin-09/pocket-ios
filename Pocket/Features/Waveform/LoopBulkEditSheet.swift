import SwiftData
import SwiftUI

/// Practice categories across a **selection** of loops (ADR 0125) — the sheet behind the
/// selection header's slider button, in the chevron's old slot.
///
/// It is a *partial* editor, and that shapes every control: each field opens on what the
/// selection already agrees on ("Multiple" when it doesn't) and stays `.unchanged` until
/// you pick something, so applying only writes what you actually touched. Tags add and
/// remove rather than replace — a selection's loops usually carry their own descriptive
/// tags, and a field that overwrote them would destroy work silently.
///
/// The Type / Focus controls are `Button` + `confirmationDialog`, **not** `Picker` or
/// `Menu`: in a `LabeledContent` value slot at a partial detent those need several taps
/// and drop the write (device bug 2026-07-10, same as `LoopEditSheet`).
struct LoopBulkEditSheet: View {
    let loops: [Loop]
    let onApply: (LoopBulkEdit) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// Tags from across the library — the suggestion pool, the convergence mechanism ADR 0034
    /// relies on so one vocabulary forms instead of per-song dialects. Loaded in `.task`, not
    /// held as a `@Query` of every `Loop`: this opens from the practice screen over playing
    /// audio, where a whole-table fetch during presentation is felt.
    @State private var tagPool: [String] = []

    @State private var edit = LoopBulkEdit()
    @State private var newTag = ""
    @State private var showingTypeOptions = false
    @State private var showingFocusOptions = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    typeRow
                    focusRow
                } header: {
                    Text("Practice")
                } footer: {
                    Text("Only what you change here is written. Everything else keeps each "
                         + "loop's own value.")
                }
                tagsSection
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // After the first frame, not during presentation — see `tagPool`.
            .task { tagPool = LibraryPools.loopTags(in: modelContext) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(edit)
                        dismiss()
                    }
                    .disabled(edit.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var title: String {
        loops.count == 1 ? "1 loop" : "\(loops.count) loops"
    }

    // MARK: Type / Focus

    private var typeRow: some View {
        LabeledContent {
            Button(typeLabel) { showingTypeOptions = true }
                .foregroundStyle(PocketColor.textSecondary)
                .confirmationDialog("Type", isPresented: $showingTypeOptions, titleVisibility: .visible) {
                    ForEach(LoopType.pickerOrder) { type in
                        Button(type == .unset ? "None" : type.label) { edit.loopType = .set(type) }
                    }
                }
        } label: {
            FieldInfoLabel(title: "Type", info: PracticeFieldInfo.loopType)
        }
    }

    /// What the button reads before you touch it: the shared value, or **Multiple** when
    /// the selection disagrees — never a value that only some of them have.
    private var typeLabel: String {
        if let chosen = edit.loopType.value { return chosen == .unset ? "None" : chosen.label }
        guard let shared = LoopSelectionSummary.commonType(of: loops) else { return "Multiple" }
        return shared == .unset ? "None" : shared.label
    }

    private var focusRow: some View {
        LabeledContent {
            Button(focusLabel) { showingFocusOptions = true }
                .foregroundStyle(PocketColor.textSecondary)
                .confirmationDialog("Focus", isPresented: $showingFocusOptions, titleVisibility: .visible) {
                    ForEach(Self.focusOptions, id: \.value) { option in
                        Button(option.label) { edit.focus = .set(option.value) }
                    }
                }
        } label: {
            FieldInfoLabel(title: "Focus", info: PracticeFieldInfo.focus)
        }
    }

    private static let focusOptions: [(value: Int?, label: String)] =
        [(nil, "Not set"), (1, "Backburner"), (2, "Active"), (3, "Sharpening")]

    private var focusLabel: String {
        if case let .set(chosen) = edit.focus {
            return Self.focusOptions.first { $0.value == chosen }?.label ?? "Not set"
        }
        // Double optional: outer nil = the selection disagrees, inner nil = they agree on
        // "never triaged". Collapsing the two would show "Multiple" for a selection that
        // in fact agrees.
        guard let shared = LoopSelectionSummary.commonFocus(of: loops) else { return "Multiple" }
        return Self.focusOptions.first { $0.value == shared }?.label ?? "Not set"
    }

    // MARK: Tags (ADR 0034)

    private var tagsSection: some View {
        Section {
            if !edit.tagsToAdd.isEmpty {
                chipCloud(edit.tagsToAdd, style: .selected) { tag in
                    edit.tagsToAdd.removeAll { $0 == tag }
                }
            }
            HStack {
                TextField("Add a tag to all", text: $newTag)
                    .submitLabel(.done)
                    .onSubmit(addTag)
                Button("Add", action: addTag)
                    .disabled(Labels.canonical(newTag) == nil)
            }
            if !tagSuggestions.isEmpty { suggestionChips }
            if !removableTags.isEmpty { removalRow }
        } header: {
            Text("Tags")
        } footer: {
            Text("Tags are added to every selected loop. Their existing tags stay.")
        }
    }

    /// Removal only offers tags **every** selected loop has — offering one that only two
    /// of five carry would make "Remove" look like it did nothing on the other three.
    private var removableTags: [String] {
        LoopSelectionSummary.sharedTags(of: loops).filter { tag in
            !edit.tagsToAdd.contains { $0.lowercased() == tag.lowercased() }
        }
    }

    private var removalRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("On all \(loops.count) — tap to remove")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            chipCloud(removableTags, style: .suggestion) { tag in
                if edit.tagsToRemove.contains(where: { $0.lowercased() == tag.lowercased() }) {
                    edit.tagsToRemove.removeAll { $0.lowercased() == tag.lowercased() }
                } else {
                    edit.tagsToRemove.append(tag)
                }
            }
        }
    }

    /// Tags used anywhere in the loop library, minus the ones already queued to add.
    private var tagSuggestions: [String] {
        Labels.suggestions(from: tagPool, excluding: edit.tagsToAdd)
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tagSuggestions, id: \.self) { suggestion in
                    TagChip(text: suggestion, style: .suggestion) {
                        edit.tagsToAdd = Labels.adding(suggestion, to: edit.tagsToAdd)
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private func chipCloud(_ tags: [String], style: TagChip.Style,
                           action: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                TagChip(text: chipText(tag), style: style) { action(tag) }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    /// A tag queued for removal reads struck-through-by-prefix, so the sheet shows the
    /// pending edit rather than requiring you to remember what you tapped.
    private func chipText(_ tag: String) -> String {
        edit.tagsToRemove.contains { $0.lowercased() == tag.lowercased() } ? "− \(tag)" : tag
    }

    private func addTag() {
        edit.tagsToAdd = Labels.adding(newTag, to: edit.tagsToAdd)
        newTag = ""
    }
}
