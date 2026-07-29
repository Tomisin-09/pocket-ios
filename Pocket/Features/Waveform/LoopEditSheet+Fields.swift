import SwiftData
import SwiftUI

// `LoopEditSheet`'s field-building sections, split into this file to keep each file under the
// 400-line cap (the sheet's core lives in `WaveformEditSheets.swift`).
extension LoopEditSheet {

    // MARK: - Journal (ADR 0067 / 0088)

    /// The loop's practice journal — now **authorable** from here (ADR 0088, reversing 0058's
    /// waveform read-only), so a song loop can be journalled without launching a run; moved off the
    /// waveform loop row into settings (ADR 0067). The row reads simply **Journal**, with the count
    /// as the unrated-style absence signal (ADR 0039): "None" until there's something to see.
    var journalSection: some View {
        Section("Journal") {
            Button {
                showingJournal = true
            } label: {
                LabeledContent {
                    Text(loop.journal.isEmpty ? "None" : "\(loop.journal.count)")
                        .foregroundStyle(PocketColor.textSecondary)
                } label: {
                    Label("Journal", systemImage: "book.closed")
                }
            }
            .accessibilityLabel(loop.journal.isEmpty
                                ? "Journal, no entries"
                                : "Journal, \(loop.journal.count) "
                                    + "entr\(loop.journal.count == 1 ? "y" : "ies")")
        }
    }

    // MARK: - Practice fields (ADR 0036)

    var practiceSection: some View {
        Section("Practice") {
            masteryRow
            focusRow
            typeRow
            commandTempoRow
            // "Practice now" (ADR 0082): appears once a command tempo is set — the same gate that
            // surfaces a loop into Practice → Loops — so setting a command tempo both makes the loop a
            // practice item and reveals the launch. Commits edits (writeEdits) so the just-set value
            // takes, then the parent runs it full-screen after the sheet dismisses.
            if commandTempo != nil {
                practiceNowButton
            }
            // "Train your ear" (ADR 0104): ears-only playback of this loop to internalise by ear —
            // ungated by command tempo (unlike Practice now), since ear training needs only audio,
            // not a measured practice target. Opens in place (not a staged full-screen run).
            earTrainingButton
        }
    }

    private var practiceNowButton: some View {
        Button {
            writeEdits()
            onPracticeNow()
            dismiss()
        } label: {
            Label("Practice now", systemImage: "play.circle.fill")
                .foregroundStyle(PocketColor.practice)
        }
        .accessibilityLabel("Practice this loop now")
    }

    private var earTrainingButton: some View {
        Button {
            // Ear training brings its own engine, so hand the host a chance to stop what it was
            // playing first (the waveform pauses) — two streams over each other is the alternative.
            onOpenEarTraining()
            showingEarTraining = true
        } label: {
            Label("Train your ear", systemImage: "ear")
                .foregroundStyle(PocketColor.journal)
        }
        .accessibilityLabel("Train your ear on this loop")
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
    var tagsSection: some View {
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
