import SwiftData
import SwiftUI

/// The practice journal (ADR 0038/0058): dated entries that snapshot a unit's context at the
/// moment of writing. Generalised over its owner — a **loop** (mastery + song-fraction command
/// tempo) or an **exercise** (absolute command BPM, no mastery) — so one sheet serves both. The
/// snapshot is immutable; only an entry's text and kind are editable.
///
/// Two modes:
/// - **Authoring** (`readOnly == false`, from the Practice run screens): a composer to add
///   entries, plus swipe-to-delete and push-to-edit on history. This is the journal's home.
/// - **Read-only** (`readOnly == true`, from the waveform screen): history only — writing moved
///   to Practice (ADR 0058), so the waveform screen just reflects past notes.
///
/// Presented at `.large` only — a journal wants room, and a single large detent keeps the
/// push-to-edit navigation clear of the medium-detent push bug (see LoopEditSheet).
struct JournalSheet: View {
    let owner: JournalOwner
    var readOnly = false
    /// Add an entry — snapshots the owner's current context. Ignored when `readOnly`.
    var onAdd: (String, EntryKind) -> Void = { _, _ in }
    /// Edit an existing entry's text + kind (snapshot stays fixed). Ignored when `readOnly`.
    var onUpdate: (JournalEntry, String, EntryKind) -> Void = { _, _, _ in }
    var onDelete: (JournalEntry) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var draftText = ""
    @State private var draftKind: EntryKind = .default

    /// Entries bucketed into day-sections, newest day + entry first (pure helper).
    private var sections: [JournalGrouping.DaySection<JournalEntry>] {
        JournalGrouping.byDay(owner.entries) { $0.createdAt }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !readOnly { composer }
                if owner.isEmpty {
                    Section { Text(emptyMessage)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary) }
                } else {
                    ForEach(sections, id: \.day) { section in
                        daySection(section)
                    }
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    /// One day's section of entries. Rows push to the editor when authoring; read-only rows are
    /// plain (no push, no swipe-delete) — the waveform screen just reflects past notes (ADR 0058).
    @ViewBuilder private func daySection(
        _ section: JournalGrouping.DaySection<JournalEntry>) -> some View {
        Section(dayHeader(section.day)) {
            ForEach(section.entries) { entry in
                if readOnly {
                    JournalEntryRow(entry: entry)
                } else {
                    NavigationLink {
                        JournalEntryEditor(entry: entry, onUpdate: onUpdate)
                    } label: {
                        JournalEntryRow(entry: entry)
                    }
                }
            }
            .onDelete(perform: readOnly ? nil : { offsets in
                offsets.map { section.entries[$0] }.forEach(onDelete)
            })
        }
    }

    /// The empty-state prompt — the authoring variant nudges what to write; the read-only variant
    /// points to the journal's new home (the Practice run screen) so it isn't a dead end.
    private var emptyMessage: String {
        if readOnly {
            return "No entries yet. Write notes from the Practice run screen — each one remembers "
                + "where you were at the time."
        }
        switch owner {
        case .loop:
            return "No entries yet. Log a goal, a breakthrough, or what's fighting back — each "
                + "entry remembers your mastery and command tempo at the time."
        case .exercise:
            return "No entries yet. Log a goal, a breakthrough, or what's fighting back — each "
                + "entry remembers your command tempo at the time."
        }
    }

    // MARK: - New-entry composer

    private var composer: some View {
        Section {
            Picker("Kind", selection: $draftKind) {
                ForEach(EntryKind.pickerOrder) { kind in
                    Text("\(kind.emoji)  \(kind.label)").tag(kind)
                }
            }
            .pickerStyle(.menu)   // self-contained → works at any detent (see LoopEditSheet)
            .foregroundStyle(PocketColor.textSecondary)

            TextField("What happened?", text: $draftText, axis: .vertical)
                .lineLimit(2...5)

            Button("Add entry") {
                onAdd(draftText, draftKind)
                draftText = ""
                draftKind = .default
            }
            // `.borderless` makes this an independent hit-target inside the Form row: without it
            // the default row-wide button swallows the first tap to dismiss the composer's focused
            // TextField instead of firing, so "Add entry" read as a dead/static button (feedback #4).
            .buttonStyle(.borderless)
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text("New entry")
        } footer: {
            capturePreview
        }
    }

    /// The "what gets saved" explainer under the composer: plain-word labels for the snapshotted
    /// values (so the bare dots / % / BPM are never cryptic) plus the immutability note.
    private var capturePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved with this entry — a snapshot of where you are right now, kept fixed even "
                + "as the unit improves:")
                .foregroundStyle(PocketColor.textSecondary)
            HStack(spacing: 6) {
                switch owner {
                case .loop(let loop):
                    Text("Mastery")
                    MasteryReadout(mastery: loop.mastery)
                    Text("·  Command tempo \(LoopProgressFormat.percentLabel(loop.commandTempo))")
                case .exercise(let exercise):
                    Text("Command tempo \(Self.bpmLabel(exercise.commandTempo))")
                }
            }
            .foregroundStyle(PocketColor.textPrimary)
        }
        .font(.futura(.footnote))
        .padding(.top, 2)
    }

    /// "Today" / "Yesterday" / a medium date for a section's day.
    private func dayHeader(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    /// Absolute-BPM label for an exercise's command snapshot — "not yet measured" when un-promoted.
    static func bpmLabel(_ bpm: Int?) -> String {
        bpm.map { "\($0) BPM" } ?? "not yet measured"
    }
}

// MARK: - Entry row

/// One journal entry, **self-describing** by owner: a loop entry shows its mastery + command-tempo
/// percent; an exercise entry shows its command BPM. Keyed off `entry.exercise` so the two
/// snapshots are never rendered in the wrong units (ADR 0058).
private struct JournalEntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                KindChip(kind: entry.kind)
                Spacer(minLength: 0)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text(entry.text)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textPrimary)
            snapshot
        }
        .padding(.vertical, 2)
    }

    /// The immutable context snapshot — where the owner's achievement stood at write time.
    @ViewBuilder private var snapshot: some View {
        if entry.exercise != nil {
            Text(JournalSheet.bpmLabel(entry.commandBpmAtEntry))
                .font(.pocketMono(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        } else {
            HStack(spacing: 8) {
                MasteryReadout(mastery: entry.masteryAtEntry)
                Text("· \(LoopProgressFormat.percentLabel(entry.commandTempoAtEntry))")
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }
}

// MARK: - Entry editor (push)

private struct JournalEntryEditor: View {
    let entry: JournalEntry
    let onUpdate: (JournalEntry, String, EntryKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var kind: EntryKind

    init(entry: JournalEntry, onUpdate: @escaping (JournalEntry, String, EntryKind) -> Void) {
        self.entry = entry
        self.onUpdate = onUpdate
        _text = State(initialValue: entry.text)
        _kind = State(initialValue: entry.kind)
    }

    var body: some View {
        Form {
            Section("Kind") {
                Picker("Kind", selection: $kind) {
                    ForEach(EntryKind.pickerOrder) { option in
                        Text("\(option.emoji)  \(option.label)").tag(option)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(PocketColor.textSecondary)
            }
            Section("Entry") {
                TextField("What happened?", text: $text, axis: .vertical)
                    .lineLimit(2...8)
            }
            // Read-only: the snapshot is fixed at creation (ADR 0038).
            Section {
                if entry.exercise != nil {
                    LabeledContent("Command tempo") {
                        Text(JournalSheet.bpmLabel(entry.commandBpmAtEntry)).font(.pocketMono(.body))
                    }
                } else {
                    LabeledContent("Mastery") { MasteryReadout(mastery: entry.masteryAtEntry) }
                    LabeledContent("Command tempo") {
                        Text(LoopProgressFormat.percentLabel(entry.commandTempoAtEntry))
                            .font(.pocketMono(.body))
                    }
                }
                LabeledContent("When") {
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.pocketMono(.body))
                }
            } header: {
                Text("Snapshot")
            } footer: {
                Text("Captured when this entry was written — fixed, so it still reflects where you "
                    + "were then, not where the unit is now.")
            }
        }
        .navigationTitle("Edit entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onUpdate(entry, text, kind)
                    dismiss()
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - Shared bits

/// A small coloured pill for an entry's kind — emoji + label. The colour mapping lives here
/// (presentation), keeping `EntryKind` itself UI-free and unit-testable.
private struct KindChip: View {
    let kind: EntryKind

    var body: some View {
        Text("\(kind.emoji)  \(kind.label)")
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.16)))
    }

    private var tint: Color {
        switch kind {
        case .goal: return .blue
        case .breakthrough: return PocketColor.active
        case .struggle: return .orange
        case .note: return PocketColor.textSecondary
        case .session: return .purple
        }
    }
}

#Preview("Journal — loop") {
    let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.85, repeats: 4)
    loop.mastery = 3
    loop.commandTempo = 0.85
    let entry = JournalEntry.forLoop(text: "Clean run at 0.85×! Pushing to full tempo next.",
                                     kind: .breakthrough, masteryAtEntry: 3, commandTempoAtEntry: 0.85)
    entry.loop = loop
    return JournalSheet(owner: .loop(loop)).preferredColorScheme(.dark)
}

#Preview("Journal — exercise") {
    let exercise = Exercise(name: "Alternating picking", currentTempo: 90, commandTempo: 120)
    let entry = JournalEntry.forExercise(text: "Held 120 clean for two minutes.",
                                         kind: .breakthrough, commandBpmAtEntry: 120)
    entry.exercise = exercise
    return JournalSheet(owner: .exercise(exercise)).preferredColorScheme(.dark)
}
