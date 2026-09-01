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
    /// "Train your ear" (ADR 0104) and "Improvise" (ADR 0135): both nested modes bring their own
    /// engine, so the parent stops whatever it was playing before either opens — otherwise two
    /// streams run over each other. One callback serves both; the host's response is identical.
    var onOpenNestedAudio: () -> Void = {}

    // The field-editing sections live in `LoopEditSheet+Fields.swift` (one type, split to stay under
    // the 400-line cap), so the state they read is `internal`, not `private` — Swift has no
    // cross-file-private for a single type. `name`/`colorChoice` stay private (only `body` uses them).
    @Environment(\.dismiss) var dismiss
    // The store, for writing journal entries straight from this sheet (ADR 0088) — journal
    // authoring is back on song loops, sharing the `JournalWriter` path with the run screen.
    @Environment(\.modelContext) private var modelContext
    // Tags already used elsewhere in the library, to suggest against (ADR 0034) — the
    // cross-song convergence read ADR 0032 forecast. Loaded in `.task` rather than held as a
    // `@Query` of every `Loop`: this sheet opens over playing audio, and fetching (and
    // faulting) the whole loop table during presentation is what made that open feel slow.
    @State var tagPool: [String] = []
    /// The reference link being added or edited (ADR 0167). Held at this level, like the journal
    /// sheet below it — a sheet presented from inside this `Form` dismisses *this* sheet instead of
    /// opening. See `ReferenceLinkEditing`.
    @State var editingReference: ReferenceLinkDraft?
    /// The picture being viewed, or the picker being opened (ADR 0167 phase 2) — held here for the
    /// same reason as `editingReference`: `.photosPicker` and `.fileImporter` are presentations too.
    @State var referenceAttachments: ReferenceAttachmentPresentation?
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
    // The favourite pin (ADR 0119). It was only settable from the Loops library's star until
    // ADR 0125 gave the selection bar a bulk star — leaving the *single* loop you're already
    // editing as the one place you couldn't set it.
    @State private var isFavorite: Bool
    // The backing-track flag (ADR 0135) — a local copy like every other field, written on Done.
    @State var isBackingTrack: Bool
    @State var newTag = ""
    // The loop's journal now lives here in settings (read-only), off the waveform row (ADR 0067).
    @State var showingJournal = false
    // "Train your ear" ear-training mode on this loop (ADR 0104) — ears-only playback + journal capture.
    @State var showingEarTraining = false
    // "Improvise" over this loop as a backing track (ADR 0135) — continuous playback + journal capture.
    @State var showingImprovise = false
    // Focus / Type pick via a bottom action sheet off a plain Button — a Menu/Picker in a
    // `LabeledContent` value slot needs several taps to register and won't commit at this sheet's
    // partial detent (device bug 2026-07-10). A Button + confirmationDialog is reliable at any detent.
    @State var showingTypeOptions = false
    @State var showingFocusOptions = false

    init(loop: Loop, autoColor: Color,
         onDelete: @escaping () -> Void, onAdjustRange: @escaping () -> Void,
         onSaved: @escaping (@escaping () -> Void) -> Void,
         onPracticeNow: @escaping () -> Void = {},
         onOpenNestedAudio: @escaping () -> Void = {}) {
        self.loop = loop
        self.autoColor = autoColor
        self.onDelete = onDelete
        self.onAdjustRange = onAdjustRange
        self.onSaved = onSaved
        self.onPracticeNow = onPracticeNow
        self.onOpenNestedAudio = onOpenNestedAudio
        _name = State(initialValue: loop.name)
        _colorChoice = State(initialValue: Self.choice(for: loop))
        _mastery = State(initialValue: loop.mastery)
        _focus = State(initialValue: loop.focus)
        _commandTempo = State(initialValue: loop.commandTempo)
        _loopType = State(initialValue: loop.loopType)
        _tags = State(initialValue: loop.tags)
        _isFavorite = State(initialValue: loop.isFavorite)
        _isBackingTrack = State(initialValue: loop.isBackingTrack)
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
        loop.focus = focus
        // Command **before** the rating, the opposite order to the Done screen's (ADR 0169). There a
        // rating is given about the run that just happened and an accepted raise then moves the
        // command off it, so the gap is real. Here the editor commits one coherent declaration — "I
        // own this at 85%, and I rate it 4" — so the rating is about the command being set in the
        // same breath, and stamping the value it is replacing would invent staleness.
        loop.commandTempo = commandTempo
        loop.rateMastery(mastery)
        loop.loopType = loopType
        loop.tags = tags
        loop.isFavorite = isFavorite
        loop.isBackingTrack = isBackingTrack
        applyColorChoice()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    ClearableTextField("Loop name", text: $name)
                    // A pin, not a grade (ADR 0119): it changes where the loop is shown — the
                    // Loops library's Favourites filter — and feeds nothing. So it sits with
                    // the name, not in Practice beside mastery and focus. **The star is the
                    // control**, tapped on and off: a switch is the wrong weight for a
                    // one-bit pin, and the filled star is the same glyph the libraries
                    // already use to mean "favourited."
                    LabeledContent("Favourite") {
                        Button {
                            isFavorite.toggle()
                            haptic(.light)
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.futura(.title3))
                                .foregroundStyle(isFavorite ? PocketColor.practice
                                                            : PocketColor.textSecondary)
                                .frame(width: 44, height: 34)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFavorite ? "Remove from favourites" : "Add to favourites")
                        .accessibilityAddTraits(isFavorite ? .isSelected : [])
                    }
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
                backingTrackSection
                journalSection
                // Where this passage is explained (ADR 0167). Beside the journal on purpose: both
                // are things you read about the loop rather than settings you tune, and both write
                // straight through rather than waiting for Done — a link is a discrete add, like a
                // journal entry, not part of the local-copy edit Cancel discards.
                ReferencesSection(owner: loop, accent: PocketColor.practice,
                                  editing: $editingReference, presenting: $referenceAttachments)
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
            // After the first frame, not during presentation — see `tagPool`.
            .task { tagPool = LibraryPools.loopTags(in: modelContext) }
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
        .referenceLinkEditing($editingReference, owner: loop, accent: PocketColor.practice)
        .referenceAttachments($referenceAttachments, naming: $editingReference, owner: loop,
                              accent: PocketColor.practice)
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
        .sheet(isPresented: $showingImprovise) {
            // The loop as a backing track (ADR 0135) — the same real audio on repeat as a bed to solo
            // over, with "what you played" notes through the same `JournalWriter` path, tagged 🎸.
            ImproviseSheet(loop: loop)
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
