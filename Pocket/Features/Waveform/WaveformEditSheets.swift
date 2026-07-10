import SwiftData
import SwiftUI

// Edit sheets for loops and markers (native system sheets), presented by tapping a row in the
// Loops/Markers panels. They edit local copies and write straight to the @Model on Done (Cancel
// discards), with an Undo snapshot handed back via `onSaved`.

struct LoopEditSheet: View {
    /// The persisted loop — edits apply straight to it on Done (so Cancel discards).
    let loop: Loop
    /// The loop's auto (start-order) colour, for the "Auto" swatch (ADR 0031).
    let autoColor: Color
    let onDelete: () -> Void
    /// Enter Fine mode on the waveform to adjust this loop's bounds.
    let onAdjustRange: () -> Void
    /// Called after Done writes edits that actually changed something, with a closure that
    /// reverts them — the parent shows an Undo toast (ADR 0019 undo, extended to saves).
    let onSaved: (@escaping () -> Void) -> Void

    @Environment(\.dismiss) private var dismiss
    // All loops across the library, to suggest tags already used elsewhere (ADR 0034) —
    // the cross-song convergence read ADR 0032 forecast, here a top-level `@Query`.
    @Query private var allLoops: [Loop]
    @State private var name: String
    @State private var colorChoice: LoopColorChoice
    // Structured practice fields (ADR 0036 slice 3) — edited as local copies, written
    // back on Done so Cancel discards. Optional: `nil` = never set (ADR 0039).
    @State private var mastery: Int?
    @State private var focus: Int?
    @State private var commandTempo: Double?
    @State private var loopType: LoopType
    // Loop tags (ADR 0034) — local copy, written back on Done.
    @State private var tags: [String]
    @State private var newTag = ""
    // The loop's journal now lives here in settings (read-only), off the waveform row (ADR 0067).
    @State private var showingJournal = false
    // Focus / Type pick via a bottom action sheet off a plain Button — a Menu/Picker in a
    // `LabeledContent` value slot needs several taps to register and won't commit at this sheet's
    // partial detent (device bug 2026-07-10). A Button + confirmationDialog is reliable at any detent.
    @State private var showingTypeOptions = false
    @State private var showingFocusOptions = false

    init(loop: Loop, autoColor: Color,
         onDelete: @escaping () -> Void, onAdjustRange: @escaping () -> Void,
         onSaved: @escaping (@escaping () -> Void) -> Void) {
        self.loop = loop
        self.autoColor = autoColor
        self.onDelete = onDelete
        self.onAdjustRange = onAdjustRange
        self.onSaved = onSaved
        _name = State(initialValue: loop.name)
        _colorChoice = State(initialValue: Self.choice(for: loop))
        _mastery = State(initialValue: loop.mastery)
        _focus = State(initialValue: loop.focus)
        _commandTempo = State(initialValue: loop.commandTempo)
        _loopType = State(initialValue: loop.loopType)
        _tags = State(initialValue: loop.tags)
    }

    /// Map the loop's stored colour fields to a picker choice (custom wins over palette).
    private static func choice(for loop: Loop) -> LoopColorChoice {
        if let hex = loop.customColorHex { return .custom(hex) }
        if let index = loop.colorIndex { return .palette(index) }
        return .auto
    }

    /// True when the chosen custom colour is low-contrast on the dark background — an
    /// advisory warning only; the colour is still allowed (ADR 0031).
    private var lowContrast: Bool {
        guard case .custom(let hex) = colorChoice, let color = HexColor.color(from: hex) else { return false }
        return !ColorContrast.isLegible(foreground: HexColor.components(of: color),
                                        background: HexColor.components(of: PocketColor.background))
    }

    /// Write the picked choice back to the loop's colour fields (custom and palette are
    /// mutually exclusive; auto clears both).
    private func applyColorChoice() {
        switch colorChoice {
        case .auto:
            loop.colorIndex = nil
            loop.customColorHex = nil
        case .palette(let index):
            loop.colorIndex = index
            loop.customColorHex = nil
        case .custom(let hex):
            loop.customColorHex = hex
            loop.colorIndex = nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    ClearableTextField("Loop name", text: $name)
                }
                Section("Range") {
                    LabeledContent("Loop") {
                        Text("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
                            .font(.pocketMono(.body))
                    }
                    Button {
                        dismiss()
                        onAdjustRange()
                    } label: {
                        Label("Adjust range on waveform", systemImage: "slider.horizontal.below.rectangle")
                    }
                }
                practiceSection
                journalSection
                tagsSection
                Section {
                    LoopColorPicker(autoColor: autoColor, choice: $colorChoice)
                } header: {
                    Text("Colour")
                } footer: {
                    if lowContrast {
                        Label("Low contrast on the dark background", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    Button("Delete loop", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit loop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let before = LoopEditSnapshot(loop)
                        loop.name = name              // mutating the @Model persists
                        loop.mastery = mastery
                        loop.focus = focus
                        loop.commandTempo = commandTempo
                        loop.loopType = loopType
                        loop.tags = tags
                        applyColorChoice()
                        // Offer an Undo only when the write actually changed something —
                        // a no-op Done shouldn't flash a toast.
                        if LoopEditSnapshot(loop) != before {
                            onSaved { before.restore(to: loop) }
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showingJournal) {
            // Read-only — authoring stays on the Practice run screen (ADR 0058).
            JournalSheet(owner: .loop(loop), readOnly: true)
        }
    }
}

// Field-building sections split into an extension (same file) to keep the type body under limit.
extension LoopEditSheet {

    // MARK: - Journal (ADR 0067)

    /// The loop's practice journal, read-only (authoring lives on the Practice run screen, ADR
    /// 0058); moved off the waveform loop row into settings (ADR 0067). The count reads as the
    /// unrated-style absence signal (ADR 0039): "None" until there's something to see.
    private var journalSection: some View {
        Section("Journal") {
            Button {
                showingJournal = true
            } label: {
                LabeledContent {
                    Text(loop.journal.isEmpty ? "None" : "\(loop.journal.count)")
                        .foregroundStyle(PocketColor.textSecondary)
                } label: {
                    Label("View entries", systemImage: "book.closed")
                }
            }
            .accessibilityLabel(loop.journal.isEmpty
                                ? "View journal, no entries"
                                : "View journal, \(loop.journal.count) "
                                    + "entr\(loop.journal.count == 1 ? "y" : "ies")")
        }
    }

    // MARK: - Practice fields (ADR 0036)

    private var practiceSection: some View {
        Section("Practice") {
            masteryRow
            focusRow
            typeRow
            commandTempoRow
        }
    }

    /// Loop type. A plain `Button` showing the current value that opens a bottom action sheet — **not**
    /// an interactive `Picker`/`Menu`, which in a `LabeledContent` value slot needs multiple taps and
    /// won't commit at this sheet's partial detent (device bug 2026-07-10). Each dialog Button's explicit
    /// `loopType =` write always lands; ⓘ stays in the independently-tappable label slot.
    private var typeRow: some View {
        LabeledContent {
            Button(loopType.label) { showingTypeOptions = true }
                .foregroundStyle(PocketColor.textSecondary)
                .confirmationDialog("Type", isPresented: $showingTypeOptions, titleVisibility: .visible) {
                    ForEach(LoopType.pickerOrder) { type in
                        Button(type == .unset ? "None" : type.label) { loopType = type }
                    }
                }
        } label: {
            FieldInfoLabel(title: "Type", info: PracticeFieldInfo.loopType)
        }
    }

    /// Mastery as a 0–5 dot rating, or unrated (`nil`, ADR 0039). Tap a dot to set that
    /// value; tapping the lowest filled dot walks it down, and walking below 1 clears it
    /// back to unrated — so the rating is always one you deliberately made.
    private var masteryRow: some View {
        LabeledContent {
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
                            // Tapping the current value walks down; below 1 → unrated (nil).
                            mastery = (mastery == value) ? (value == 1 ? nil : value - 1) : value
                        }
                        .accessibilityLabel("Set mastery to \(value)")
                }
            }
        } label: {
            FieldInfoLabel(title: "Mastery", info: PracticeFieldInfo.mastery)
        }
    }

    /// Practice intent — Backburner / Active / Sharpening, or Not set (`nil`, ADR 0039). Stored as
    /// `Int?` per ADR 0036 (the planner reads the raw value); labels live in the view. Same Button +
    /// action-sheet pattern as `typeRow` (a Menu/Picker here won't commit, device bug 2026-07-10);
    /// each dialog Button writes `focus` directly.
    private var focusRow: some View {
        LabeledContent {
            Button(focusLabel) { showingFocusOptions = true }
                .foregroundStyle(PocketColor.textSecondary)
                .confirmationDialog("Focus", isPresented: $showingFocusOptions, titleVisibility: .visible) {
                    ForEach(Self.focusOptions, id: \.value) { option in
                        Button(option.label) { focus = option.value }
                    }
                }
        } label: {
            FieldInfoLabel(title: "Focus", info: PracticeFieldInfo.focus)
        }
    }

    /// The focus intents in dialog order (`nil` = Not set), shared by the action sheet and the label.
    private static let focusOptions: [(value: Int?, label: String)] =
        [(nil, "Not set"), (1, "Backburner"), (2, "Active"), (3, "Sharpening")]

    private var focusLabel: String {
        Self.focusOptions.first { $0.value == focus }?.label ?? "Not set"
    }

    /// Command tempo as a percentage of original (ADR 0036), or not yet measured (`nil`, ADR 0039).
    /// A slider can't express "unset," so when unmeasured the row offers a **Set** button (seeded
    /// from the loop's practice `speed`); once set, the slider shows with a **Clear** back to unset.
    private var commandTempoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let value = commandTempo {
                LabeledContent {
                    HStack(spacing: 12) {
                        Text(LoopProgressFormat.percentLabel(value))
                            .font(.pocketMono(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                        Button("Clear") { commandTempo = nil }
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                } label: {
                    FieldInfoLabel(title: "Command tempo", info: PracticeFieldInfo.commandTempo)
                }
                Slider(value: Binding(get: { value }, set: { commandTempo = $0 }),
                       in: 0.25...1.5, step: 0.05)
            } else {
                LabeledContent {
                    Button("Set") { commandTempo = min(max(loop.speed, 0.25), 1.5) }
                } label: {
                    FieldInfoLabel(title: "Command tempo", info: PracticeFieldInfo.commandTempo)
                }
            }
        }
    }

    // MARK: - Tags (ADR 0034)

    /// The loop's descriptive tags: those already applied render as removable `selected` chips in a
    /// wrapping cloud; below sits an add field and `suggestion` chips drawn from tags used on any
    /// loop in the library (the convergence mechanism). One vocabulary, add/remove symmetric (ADR 0034).
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
            HStack {
                TextField("Add a tag", text: $newTag)
                    .submitLabel(.done)
                    .onSubmit(addTag)
                Button("Add", action: addTag)
                    .disabled(Labels.canonical(newTag) == nil)
            }
            if !skillTagSuggestions.isEmpty {
                skillTagChips
            }
            if !tagSuggestions.isEmpty {
                tagSuggestionChips
            }
        }
    }

    /// The **skill-bucket** suggestions (V2 planner Slice 4): tagging a loop with one lets the
    /// planner's technique goals surface it (Path A). Always present (not drawn from other loops),
    /// excludes buckets already on this loop, prefixed ✨ so it reads apart from descriptive tags.
    private var skillTagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(skillTagSuggestions, id: \.self) { suggestion in
                    TagChip(text: "✨ \(suggestion)", style: .suggestion) {
                        tags = Labels.adding(suggestion, to: tags)
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    /// The recognised skill-bucket tags not already applied to this loop, in canonical order.
    private var skillTagSuggestions: [String] {
        let applied = Set(tags.map { $0.lowercased() })
        return SkillFamilyMap.suggestedLoopTags.filter { !applied.contains($0.lowercased()) }
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
        Labels.suggestions(from: allLoops.flatMap(\.tags), excluding: tags)
    }

    /// Canonicalise and de-dup case-insensitively through the shared normaliser (ADR 0034,
    /// reusing ADR 0033's machinery) so the tag set never fragments into needs-work / Needs-work.
    private func addTag() {
        tags = Labels.adding(newTag, to: tags)
        newTag = ""
    }
}

#Preview("Edit loop") {
    let song = Song.sample()
    let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.85, repeats: 4)
    loop.song = song
    loop.mastery = 3
    loop.focus = 2
    loop.commandTempo = 0.85
    loop.loopType = .riff
    loop.tags = ["solo", "needs-work"]
    return LoopEditSheet(loop: loop, autoColor: PocketColor.marker,
                         onDelete: {}, onAdjustRange: {}, onSaved: { _ in })
        .preferredColorScheme(.dark)
}
