import SwiftData
import SwiftUI

// Edit sheets for loops and markers (brief: native system sheets). Tapping a
// row in the Loops/Markers panels presents these. They take a snapshot of the
// item, edit local copies, and hand the result back via `onSave` / `onDelete`
// so the screen owns the source of truth.

struct LoopEditSheet: View {
    /// The persisted loop — edits apply straight to it on Done (so Cancel discards).
    let loop: Loop
    /// The loop's auto (start-order) colour, for the "Auto" swatch (ADR 0031).
    let autoColor: Color
    let onDelete: () -> Void
    /// Enter Fine mode on the waveform to adjust this loop's bounds.
    let onAdjustRange: () -> Void

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

    init(loop: Loop, autoColor: Color,
         onDelete: @escaping () -> Void, onAdjustRange: @escaping () -> Void) {
        self.loop = loop
        self.autoColor = autoColor
        self.onDelete = onDelete
        self.onAdjustRange = onAdjustRange
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
                        loop.name = name              // mutating the @Model persists
                        loop.mastery = mastery
                        loop.focus = focus
                        loop.commandTempo = commandTempo
                        loop.loopType = loopType
                        loop.tags = tags
                        applyColorChoice()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

    /// Loop type. `.menu` (not the Form default navigation-link style): this sheet opens at the
    /// `.medium` detent, and a navigation-link Picker can't push its options list out of a
    /// partial-height sheet — the push is swallowed, so the value never changes. A menu dropdown
    /// is self-contained and works at any detent. Wrapped in `LabeledContent` so the ⓘ sits in the
    /// (independently tappable) label slot while the menu owns the trailing value.
    private var typeRow: some View {
        LabeledContent {
            Picker("Type", selection: $loopType) {
                ForEach(LoopType.pickerOrder) { type in
                    Text(type.label).tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .foregroundStyle(PocketColor.textSecondary)
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
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.textSecondary)
                }
                ForEach(1...5, id: \.self) { value in
                    Circle()
                        .fill(value <= (mastery ?? 0) ? PocketColor.marker : PocketColor.barDefault)
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

    /// Practice intent — Backburner / Active / Sharpening, or Not set (`nil`, ADR 0039).
    /// A menu (not a segmented control): a 4th "unset" segment is too cramped on a phone,
    /// and a menu handles `nil` cleanly while matching the `Type` menu above it. Stored as
    /// `Int?` per ADR 0036 (the planner reads the raw value); labels live in the view. Wrapped in
    /// `LabeledContent` so the ⓘ stays independently tappable (a menu Picker's row swallows taps).
    private var focusRow: some View {
        LabeledContent {
            Picker("Focus", selection: $focus) {
                Text("Not set").tag(Int?.none)
                Text("Backburner").tag(Int?(1))
                Text("Active").tag(Int?(2))
                Text("Sharpening").tag(Int?(3))
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .foregroundStyle(PocketColor.textSecondary)
        } label: {
            FieldInfoLabel(title: "Focus", info: PracticeFieldInfo.focus)
        }
    }

    /// Command tempo as a percentage of original (ADR 0036), or not yet measured (`nil`,
    /// ADR 0039). A slider can't express "unset," so when unmeasured the row offers a
    /// **Set** button (seeded from the loop's current practice `speed`, a tempo you're
    /// demonstrably at); once set, the slider shows with a **Clear** control back to unset.
    private var commandTempoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let value = commandTempo {
                LabeledContent {
                    HStack(spacing: 12) {
                        Text(LoopProgressFormat.percentLabel(value))
                            .font(.pocketMono(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                        Button("Clear") { commandTempo = nil }
                            .font(.caption)
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

    /// The loop's descriptive tags. The tags already on this loop render as removable
    /// `selected` chips (tap the ✕ to remove) in a wrapping cloud so they're all visible at
    /// a glance; below sits an add field and a row of `suggestion` chips drawn from tags used
    /// on any loop in the library (the convergence mechanism — many loops sharing the *same*
    /// tag). One chip vocabulary, add and remove symmetric (ADR 0034).
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
            if !tagSuggestions.isEmpty {
                tagSuggestionChips
            }
        }
    }

    /// Tappable chips of tags already used on other loops — tap to add the canonical form.
    /// Horizontally scrolling (not wrapped) since the library-wide set can be long.
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

    /// Distinct, normalised tags used across every loop in the library, excluding those
    /// already on this loop. The flat-map is the loop-set aggregation (ADR 0034 slice 1);
    /// `Labels.suggestions` does the distinct/normalise/exclude/sort, shared with collections.
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

struct MarkerEditSheet: View {
    let marker: Marker
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label: String

    init(marker: Marker, onDelete: @escaping () -> Void) {
        self.marker = marker
        self.onDelete = onDelete
        _label = State(initialValue: marker.label)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    ClearableTextField("Marker name", text: $label)
                }
                Section("Position") {
                    LabeledContent("At") {
                        Text(timecode(marker.seconds)).font(.pocketMono(.body))
                    }
                }
                Section {
                    Button("Delete marker", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        marker.label = label
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
                         onDelete: {}, onAdjustRange: {})
        .preferredColorScheme(.dark)
}
