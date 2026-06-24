import SwiftData
import SwiftUI

// The loop practice journal (ADR 0038): dated entries that snapshot the loop's
// mastery + command tempo at the moment of writing. Opened from the book icon on the
// loop row. The snapshot is immutable; only an entry's text and kind are editable.
// Presented at `.large` only — a journal wants room, and a single large detent keeps
// the push-to-edit navigation clear of the medium-detent push bug (see LoopEditSheet).

struct LoopJournalSheet: View {
    let loop: Loop
    /// Add an entry — snapshots the loop's current mastery + command tempo.
    let onAdd: (String, EntryKind) -> Void
    /// Edit an existing entry's text + kind (snapshot stays fixed).
    let onUpdate: (JournalEntry, String, EntryKind) -> Void
    let onDelete: (JournalEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftText = ""
    @State private var draftKind: EntryKind = .default

    /// Entries bucketed into day-sections, newest day + entry first (pure helper).
    private var sections: [JournalGrouping.DaySection<JournalEntry>] {
        JournalGrouping.byDay(loop.journal) { $0.createdAt }
    }

    var body: some View {
        NavigationStack {
            Form {
                composer
                if loop.journal.isEmpty {
                    Section {
                        Text("No entries yet. Log a goal, a breakthrough, or what's "
                            + "fighting back — each entry remembers your mastery and "
                            + "command tempo at the time.")
                            .font(.footnote)
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                } else {
                    ForEach(sections, id: \.day) { section in
                        Section(dayHeader(section.day)) {
                            ForEach(section.entries) { entry in
                                NavigationLink {
                                    JournalEntryEditor(entry: entry, onUpdate: onUpdate)
                                } label: {
                                    JournalEntryRow(entry: entry)
                                }
                            }
                            .onDelete { offsets in
                                offsets.map { section.entries[$0] }.forEach(onDelete)
                            }
                        }
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
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text("New entry")
        } footer: {
            // Spell out exactly what the entry records and that it's frozen — so the
            // musician knows every entry is a dated snapshot, not just free text.
            capturePreview
        }
    }

    /// The "what gets saved" explainer under the composer: plain-word labels for the
    /// two snapshotted values (so the bare dots / % are never cryptic) plus a line
    /// making the immutability explicit.
    private var capturePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved with this entry — a snapshot of where you are right now, kept "
                + "fixed even as the loop improves:")
                .foregroundStyle(PocketColor.textSecondary)
            HStack(spacing: 6) {
                Text("Mastery")
                MasteryReadout(mastery: loop.mastery)
                Text("·  Command tempo \(LoopProgressFormat.percentLabel(loop.commandTempo))")
            }
            .foregroundStyle(PocketColor.textPrimary)
        }
        .font(.footnote)
        .padding(.top, 2)
    }

    /// "Today" / "Yesterday" / a medium date for a section's day.
    private func dayHeader(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Entry row

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
                .font(.subheadline)
                .foregroundStyle(PocketColor.textPrimary)
            // The immutable context snapshot — where mastery + command tempo stood.
            HStack(spacing: 8) {
                MasteryReadout(mastery: entry.masteryAtEntry)
                Text("· \(LoopProgressFormat.percentLabel(entry.commandTempoAtEntry))")
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .padding(.vertical, 2)
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
                LabeledContent("Mastery") { MasteryReadout(mastery: entry.masteryAtEntry) }
                LabeledContent("Command tempo") {
                    Text(LoopProgressFormat.percentLabel(entry.commandTempoAtEntry))
                        .font(.pocketMono(.body))
                }
                LabeledContent("When") {
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.pocketMono(.body))
                }
            } header: {
                Text("Snapshot")
            } footer: {
                Text("Captured when this entry was written — fixed, so it still reflects "
                    + "where you were then, not where the loop is now.")
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

/// A small coloured pill for an entry's kind — emoji + label. The colour mapping lives
/// here (presentation), keeping `EntryKind` itself UI-free and unit-testable.
private struct KindChip: View {
    let kind: EntryKind

    var body: some View {
        Text("\(kind.emoji)  \(kind.label)")
            .font(.caption.weight(.semibold))
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

#Preview("Loop journal") {
    let song = Song.sample()
    let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.85, repeats: 4)
    loop.song = song
    loop.mastery = 3
    loop.commandTempo = 0.85
    let now = Date()
    let first = JournalEntry(text: "Bend at the top still sharp — slow it to 70%.",
                             kind: .struggle, masteryAtEntry: 2, commandTempoAtEntry: 0.7,
                             createdAt: now.addingTimeInterval(-90_000))
    let second = JournalEntry(text: "Clean run at 0.85×! Pushing to full tempo next.",
                              kind: .breakthrough, masteryAtEntry: 3, commandTempoAtEntry: 0.85,
                              createdAt: now)
    first.loop = loop
    second.loop = loop
    return LoopJournalSheet(loop: loop, onAdd: { _, _ in }, onUpdate: { _, _, _ in }, onDelete: { _ in })
        .preferredColorScheme(.dark)
}
