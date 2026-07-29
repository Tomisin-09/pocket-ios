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
    /// "Practice now" (ADR 0082): the parent stages this loop for a full-screen training run,
    /// launched once the sheet dismisses. Shown only when a command tempo is set.
    var onPracticeNow: () -> Void = {}
    /// "Train your ear" (ADR 0104): the ear-training sheet brings its own engine, so the parent stops
    /// whatever it was playing before it opens — otherwise both stream at once.
    var onOpenEarTraining: () -> Void = {}

    // The field-editing sections live in `LoopEditSheet+Fields.swift` (one type, split to stay under
    // the 400-line cap), so the state they read is `internal`, not `private` — Swift has no
    // cross-file-private for a single type. `name`/`colorChoice` stay private (only `body` uses them).
    @Environment(\.dismiss) var dismiss
    // The store, for writing journal entries straight from this sheet (ADR 0088) — journal
    // authoring is back on song loops, sharing the `JournalWriter` path with the run screen.
    @Environment(\.modelContext) private var modelContext
    // All loops across the library, to suggest tags already used elsewhere (ADR 0034) —
    // the cross-song convergence read ADR 0032 forecast, here a top-level `@Query`.
    @Query var allLoops: [Loop]
    @State private var name: String
    @State private var colorChoice: LoopColorChoice
    // Structured practice fields (ADR 0036 slice 3) — edited as local copies, written
    // back on Done so Cancel discards. Optional: `nil` = never set (ADR 0039).
    @State var mastery: Int?
    @State var focus: Int?
    @State var commandTempo: Double?
    @State var loopType: LoopType
    // Loop tags (ADR 0034) — local copy, written back on Done.
    @State var tags: [String]
    @State var newTag = ""
    // The loop's journal now lives here in settings (read-only), off the waveform row (ADR 0067).
    @State var showingJournal = false
    // "Train your ear" ear-training mode on this loop (ADR 0104) — ears-only playback + journal capture.
    @State var showingEarTraining = false
    // Focus / Type pick via a bottom action sheet off a plain Button — a Menu/Picker in a
    // `LabeledContent` value slot needs several taps to register and won't commit at this sheet's
    // partial detent (device bug 2026-07-10). A Button + confirmationDialog is reliable at any detent.
    @State var showingTypeOptions = false
    @State var showingFocusOptions = false

    init(loop: Loop, autoColor: Color,
         onDelete: @escaping () -> Void, onAdjustRange: @escaping () -> Void,
         onSaved: @escaping (@escaping () -> Void) -> Void,
         onPracticeNow: @escaping () -> Void = {},
         onOpenEarTraining: @escaping () -> Void = {}) {
        self.loop = loop
        self.autoColor = autoColor
        self.onDelete = onDelete
        self.onAdjustRange = onAdjustRange
        self.onSaved = onSaved
        self.onPracticeNow = onPracticeNow
        self.onOpenEarTraining = onOpenEarTraining
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

    /// Write the local edits straight to the @Model (mutation persists). Shared by **Done** and
    /// **Practice now** (ADR 0082, in `+Fields`) so launching a run commits the edits you just made —
    /// a command tempo set moments ago takes before the run seeds from the loop.
    func writeEdits() {
        loop.name = name
        loop.mastery = mastery
        loop.focus = focus
        loop.commandTempo = commandTempo
        loop.loopType = loopType
        loop.tags = tags
        applyColorChoice()
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
                        writeEdits()
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
            // Authorable again from song loops (ADR 0088, reversing 0058's waveform read-only) —
            // the same `JournalWriter` path the Practice run screen uses, each entry snapshotting
            // the loop's mastery + command tempo at write time.
            JournalSheet(owner: .loop(loop),
                         onAdd: { text, kind in
                             if JournalWriter.add(to: .loop(loop), text: text, kind: kind,
                                                  into: modelContext) {
                                 try? modelContext.save(); haptic(.light)
                             }
                         },
                         onUpdate: { entry, text, kind in
                             JournalWriter.update(entry, text: text, kind: kind)
                             try? modelContext.save()
                         },
                         onDelete: { entry in
                             JournalWriter.delete(entry, from: modelContext)
                             try? modelContext.save(); haptic(.light)
                         })
        }
        .sheet(isPresented: $showingEarTraining) {
            // Ears-only ear training on this loop (ADR 0104) — plays the loop's real audio and captures
            // "what you heard" notes back through the same `JournalWriter` path, tagged 👂.
            EarTrainingSheet(loop: loop)
        }
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
