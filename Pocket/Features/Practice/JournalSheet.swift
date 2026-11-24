import SwiftData
import SwiftUI

/// The practice journal (ADR 0038/0058/0088): dated entries that snapshot a unit's context at the
/// moment of writing. Generalised over its owner — a **loop** (mastery + song-fraction command
/// tempo) or an **exercise** (absolute command BPM, no mastery) — so one sheet serves both. The
/// snapshot is immutable; only an entry's text and kind are editable.
///
/// Always **authoring**: a composer to add entries, plus swipe-to-delete and push-to-edit on
/// history. Reached from the Practice run screens and (ADR 0088, reversing 0058's waveform
/// read-only) the loop edit sheet — writing a song loop's journal no longer needs a run.
///
/// The sheet writes through `JournalWriter` and saves itself (ADR 0318). Until then each of its four
/// hosts passed the same three callbacks, and a host that passed none (the freeform block did, once)
/// got a journal whose Add, edit and delete did nothing. Saving here is also what lets a failed save
/// say so on the sheet, where the player is, rather than on the screen underneath it.
///
/// Presented at `.large` only — a journal wants room, and a single large detent keeps the
/// push-to-edit navigation clear of the medium-detent push bug (see LoopEditSheet).
struct JournalSheet: View {
    let owner: JournalOwner

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draftText = ""
    @State private var saveFailed = false
    @State private var draftKind: EntryKind = .default
    @FocusState private var draftFocused: Bool

    /// Entries bucketed into day-sections, newest day + entry first (pure helper).
    private var sections: [JournalGrouping.DaySection<JournalEntry>] {
        JournalGrouping.byDay(owner.entries) { $0.createdAt }
    }

    /// The "Add entry" primary button gates on real content — enabled only once the draft
    /// holds non-whitespace text (P3).
    private var canAdd: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Free for good (ADR 0263 D1), so the screen carries no `PlanGated`.
    var body: some View {
        NavigationStack {
            KeyboardFollowingScroll {
                Form {
                    composer
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
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .saveFailedAlert(isPresented: $saveFailed, retry: commitAdd)
        .presentationDetents([.large])
    }

    /// Add an entry, snapshotting the owner's context as it is now (ADR 0058). An empty draft writes
    /// nothing. The draft clears either way: the entry is in the list, saved or not.
    private func addEntry() {
        if JournalWriter.add(to: owner, text: draftText, kind: draftKind, into: modelContext) {
            commitAdd()
        }
        draftText = ""
        draftKind = .default
    }

    /// The save after an add, which *Try again* repeats without writing the entry twice (ADR 0318).
    private func commitAdd() {
        guard modelContext.saveOrLog() else { saveFailed = true; return }
        haptic(.light)
    }

    /// A delete that fails to save only comes back after a relaunch, so it logs and says nothing (0318).
    private func delete(_ entry: JournalEntry) {
        JournalWriter.delete(entry, from: modelContext)
        modelContext.saveOrLog()
        haptic(.light)
    }

    /// One day's section of entries. Rows push to the editor; swipe-to-delete removes an entry.
    @ViewBuilder private func daySection(
        _ section: JournalGrouping.DaySection<JournalEntry>) -> some View {
        Section(dayHeader(section.day)) {
            ForEach(section.entries) { entry in
                NavigationLink {
                    JournalEntryEditor(entry: entry)
                } label: {
                    JournalEntryRow(entry: entry, ownerLabel: nil)
                }
            }
            .onDelete { offsets in
                offsets.map { section.entries[$0] }.forEach(delete)
            }
        }
    }

    /// The empty-state prompt — nudges what to write.
    ///
    /// Says **write**, never *log*: ADR 0176 gives "practice log" to the counted-up screen, and one
    /// word cannot be both the noun for minutes the app records by itself and the verb for a
    /// sentence the player types.
    private var emptyMessage: String {
        switch owner {
        case .loop:
            return "No entries yet. Write down a goal, a breakthrough, or what's fighting back — each "
                + "entry remembers your mastery and command tempo at the time."
        case .exercise:
            return "No entries yet. Write down a goal, a breakthrough, or what's fighting back — each "
                + "entry remembers your command tempo at the time."
        case .session:
            // Unreachable — this sheet is presented per *unit*, and a session owner holds no journal
            // to browse (ADR 0143). Written out rather than defaulted so the string stays true if a
            // later surface ever does hand one over.
            return "No entries yet. Write down how a session went — each entry remembers what you practised."
        case .standalone:
            // Unreachable for the same reason `.session` is, and one step further: a standalone owner
            // holds no journal *and* snapshots nothing (ADR 0155). If a later surface ever does hand
            // one over, the string must not promise a snapshot the entry will never carry.
            return "No entries yet. Jot a goal, a breakthrough or a struggle."
        case .metronome:
            // Unreachable for the same reason (ADR 0160) — a metronome owner holds no journal either.
            // It *does* snapshot, unlike `.standalone`, so the string is allowed to promise one.
            return "No entries yet. Jot what the click is telling you — each entry remembers the "
                + "tempo and meter you were playing to."
        }
    }

    // MARK: - New-entry composer

    @ViewBuilder private var composer: some View {
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
                .scrollsIntoViewWhenFocused("composer", focused: $draftFocused)
        } header: {
            Text("New entry")
        }

        // The primary button lives in its own section (P3): a full-width pill floating on a
        // clear row, separated from the input fields' grouped container by the standard
        // section gap — so its rounded corners no longer nest awkwardly into the text field's.
        Section {
            Button(action: addEntry) {
                Text("Add entry")
                    .font(.futura(.headline))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(canAdd ? PocketColor.background : PocketColor.textSecondary)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(canAdd ? PocketColor.practiceCTA : PocketColor.surfaceBorder))
            }
            // `.borderless` makes this an independent hit-target inside the Form row: without it
            // the default row-wide button swallows the first tap to dismiss the composer's focused
            // TextField instead of firing, so "Add entry" read as a dead/static button (feedback #4).
            .buttonStyle(.borderless)
            .disabled(!canAdd)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
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
                    // Previews exactly what the snapshot will hold, rhythm included (ADR 0121).
                    Text("Command tempo "
                         + Self.bpmLabel(exercise.commandTempo,
                                         notesPerBeat: exercise.commandNotesPerBeat))
                case .session(let session):
                    // Unreachable here (see `emptyMessage`), but a session's snapshot is a list of
                    // units, never a tempo — so it must never fall through to a unit's preview.
                    Text(session.units.isEmpty
                         ? "What you practised"
                         : session.units.map(\.title).joined(separator: ", "))
                case .standalone:
                    // Unreachable here too, and the only owner with genuinely nothing to preview —
                    // a standalone note snapshots nothing at all (ADR 0155 §5), so this says so
                    // rather than showing an empty row that reads as a missing value.
                    Text("Nothing — this note isn't attached to a loop or exercise")
                case .metronome(let sitting):
                    // Unreachable here too, but a metronome note is the one ownerless entry that
                    // *does* carry a snapshot (ADR 0160), so it previews the sitting rather than
                    // borrowing `.standalone`'s "nothing".
                    Text(sitting.summary)
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

    /// The BPM label now lives on `LoopProgressFormat`, beside its `percentLabel` sibling and free of
    /// `@MainActor` (ADR 0207 D9). Kept here as a forwarding alias because four call sites and a test
    /// comment name it through this type, and renaming those is churn with no reader benefit.
    static func bpmLabel(_ bpm: Int?, notesPerBeat: Int? = nil) -> String {
        LoopProgressFormat.bpmLabel(bpm, notesPerBeat: notesPerBeat)
    }
}

// MARK: - Entry editor (push)

private struct JournalEntryEditor: View {
    let entry: JournalEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var text: String
    @State private var kind: EntryKind
    @State private var saveFailed = false
    @FocusState private var textFocused: Bool

    init(entry: JournalEntry) {
        self.entry = entry
        _text = State(initialValue: entry.text)
        _kind = State(initialValue: entry.kind)
    }

    var body: some View {
        KeyboardFollowingScroll {
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
                        .scrollsIntoViewWhenFocused("entry", focused: $textFocused)
                }
                // Read-only: the snapshot is fixed at creation (ADR 0038). Keyed on `ownerKind`, the
                // single discriminator (ADR 0143) — the hand-written `entry.exercise != nil` this
                // replaces would have shown a session entry a loop's mastery row.
                Section {
                    switch entry.ownerKind {
                    case .exercise:
                        // Gated on the value, unlike the loop case below (ADR 0169). Exercise entries
                        // only started snapshotting a rating here; every entry written before that
                        // holds `nil` meaning *unrecorded*, and `MasteryReadout` renders `nil` as
                        // "Unrated" — a claim about the player rather than about the record. Showing
                        // no row is what those entries have always shown, and it is the truth.
                        if entry.masteryAtEntry != nil {
                            LabeledContent("Mastery") { MasteryReadout(mastery: entry.masteryAtEntry) }
                        }
                        LabeledContent("Command tempo") {
                            Text(JournalSheet.bpmLabel(entry.commandBpmAtEntry,
                                                       notesPerBeat: entry.commandNotesPerBeatAtEntry))
                                .font(.pocketMono(.body))
                        }
                    case .loop:
                        LabeledContent("Mastery") { MasteryReadout(mastery: entry.masteryAtEntry) }
                        LabeledContent("Command tempo") {
                            Text(LoopProgressFormat.percentLabel(entry.commandTempoAtEntry))
                                .font(.pocketMono(.body))
                        }
                    case .session:
                        // A session spans several units at several tempos, so there is no one number
                        // to show; what it snapshotted is what was practised.
                        LabeledContent("Practised") {
                            Text(entry.practisedUnits.map(\.title).joined(separator: ", "))
                                .font(.futura(.body))
                                .multilineTextAlignment(.trailing)
                        }
                    case .metronome:
                        // The click it was written at (ADR 0160). Unreachable today for the same
                        // reason a standalone entry is — there is no owner screen to edit it from —
                        // but it must never fall through to "no snapshot", which is what it isn't.
                        if let sitting = entry.metronomeContext {
                            LabeledContent("Metronome") {
                                Text(sitting.summary).font(.pocketMono(.body))
                            }
                        }
                    case .standalone, .orphan:
                        // Neither has a snapshot to show. A standalone entry can't reach this form
                        // at all today — editing lives on the owner's screen and it has none (ADR
                        // 0155 §4) — but it shares the orphan's rendering wherever it is seen.
                        EmptyView()
                    }
                    LabeledContent("When") {
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.pocketMono(.body))
                    }
                } header: {
                    Text("Snapshot")
                } footer: {
                    Text("Captured when this entry was written — fixed, so it still reflects where "
                        + "you were then, not where the unit is now.")
                }
            }
        }
        .navigationTitle("Edit entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // The snapshot stays fixed; only the text and kind change.
                    JournalWriter.update(entry, text: text, kind: kind)
                    commit()
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .saveFailedAlert(isPresented: $saveFailed, retry: commit)
    }

    /// The save and the pop back, which *Try again* repeats. A failed save stays on the editor (ADR 0318).
    private func commit() {
        guard modelContext.saveOrLog() else { saveFailed = true; return }
        dismiss()
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
