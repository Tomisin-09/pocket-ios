import SwiftData
import SwiftUI

/// **Write a tab** (ADR 0235 D3, D4): a title, the strip with its one open slot, a **+**, then *Bar line* and
/// *Section*, Name the notes' neck (`NeckNoteEditor`) in Toolkit's indigo, and *The tab so far*. A tap on the
/// neck fills the + with a new note and moves on, silently; pick a note to change it, put one in before it,
/// or take it out. Every change is one step of ↶ ↷, bar lines and sections included, for the visit.
///
/// **It saves as you go.** The tab is made on its first note or first letter of title, so a tab left with
/// nothing in it is never kept (D2); a tab this visit made and emptied again goes when the writer closes.
/// **Done** goes back.
struct TabWriterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Key.accidentalPreference) private var accidentalRaw = NoteSpelling.default.rawValue

    /// The tab being written, `nil` until there's something to keep.
    @State private var tab: WrittenTab?
    /// Whether this visit made the tab: only then may closing the writer delete it.
    @State private var madeHere: Bool
    @State private var title: String
    @State var draft: TabDraft
    @State var history = EditHistory<TabStep>()
    @State var tuning: NamingTuning
    @State private var showingInstrument = false
    /// The fret the neck scrolls to: set when a note is picked, never on a tap, so placing a note never slides
    /// the board out from under the finger (0227 D2).
    @State var neckTarget: Int?
    /// *Section* open under the strip.
    @State var naming = false

    init(tab: WrittenTab?) {
        let payload = tab?.payload
        let draft = TabDraft(content: payload?.content ?? TabContent())
        let tuner = CountTheNotesModel.tunerTuning()
        _tab = State(initialValue: tab)
        _madeHere = State(initialValue: tab == nil)
        _title = State(initialValue: tab?.title ?? "")
        _draft = State(initialValue: draft)
        _tuning = State(initialValue: NamingTuning(openMidi: payload?.openMidi ?? tuner.openMidi,
                                                   label: payload?.tuningLabel ?? tuner.label))
        _neckTarget = State(initialValue: draft.marked.flatMap { NameTheNotesSheet.fret(of: draft.content.labels[$0]) })
    }

    var spelling: NoteSpelling { NoteSpelling(rawValue: accidentalRaw) ?? .default }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Name this tab", text: $title)
                    .font(.futura(.title3, weight: .semibold))
                    .submitLabel(.done)
                    .accessibilityIdentifier("tab.title")
                Divider()
                stripHeader
                strip
                stripLine
                controls
                if naming {
                    TabSectionNamer(position: draft.position, count: draft.count,
                                    current: draft.content.section(startingAt: draft.position)?.name,
                                    onSave: { name in change { $0.setSection(name) }; naming = false },
                                    onRemove: { change { $0.setSection(nil) }; naming = false },
                                    onCancel: { naming = false })
                }
                NeckNoteEditor(answers: draft.editorLabels, cursor: cursor, tuning: tuning, spelling: spelling,
                               noun: "note", voice: .writing, scrollTarget: neckTarget,
                               write: { labels in change { $0.write(editorLabels: labels) } },
                               onPlace: { string, fret in change { $0.place(string: string, fret: fret) } },
                               onInstrument: { showingInstrument = true })
                    .environment(\.neckAccent, PocketColor.toolkit)
                soFar
            }
            .padding(20)
            .readableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(madeHere ? "New tab" : "Edit tab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .tint(PocketColor.toolkit)
        .sheet(isPresented: $showingInstrument) {
            NamingInstrumentSheet(current: tuning, placed: NamingTuning.placed(in: draft.content.labels)) { next in
                retune(to: next)
            }
        }
        .onChange(of: title) { persist() }
        .onAppear { Analytics.send(.toolOpened(tool: .tabWriter)) }
        .onDisappear { finish() }
    }

    /// The editor's cursor: read from the draft, and only its ringed string, *Chords* and *Into it* written
    /// back. Where the writer is stays the draft's to say.
    private var cursor: Binding<NeckCursor> {
        Binding(get: { draft.cursor }, set: { draft.adopt($0) })
    }

    // MARK: - The tab so far

    @ViewBuilder private var soFar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The tab so far")
                .font(.futura(.subheadline, weight: .semibold))
            if draft.isEmpty {
                Text("Nothing placed yet. Tap the neck to add the first note.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                PieceDrawing(notes: notes, spelling: spelling)
            }
        }
        .padding(.top, 8)
    }

    /// What's written, ready to draw and to keep.
    var notes: PieceNotes {
        PieceNotes(labels: draft.content.labels, openMidi: tuning.openMidi, tuningLabel: tuning.label,
                   bars: draft.content.bars, sections: draft.content.sections)
    }

    // MARK: - Changes, history and saving

    /// Every change goes through here: one step of the history, then saved.
    func change(_ edit: (inout TabDraft) -> Void) {
        let before = step
        edit(&draft)
        history.record(before, now: step)
        persist()
    }

    /// The writer as a step: the draft's, with the strings.
    var step: TabStep {
        var step = draft.step
        step.openMidi = tuning.openMidi
        step.tuningLabel = tuning.label
        return step
    }

    func restore(_ step: TabStep) {
        draft.restore(step)
        if !step.openMidi.isEmpty { tuning = NamingTuning(openMidi: step.openMidi, label: step.tuningLabel) }
        naming = false
        persist()
    }

    /// New strings: a new tuning keeps the frets, a new instrument clears them, as one step ↶ brings back.
    private func retune(to next: NamingTuning) {
        let before = step
        draft.retune(tuning.carrying(draft.content.labels, to: next))
        tuning = next
        history.record(before, now: step)
        persist()
    }

    /// Write the tab as it stands, making it on its first note or letter of title.
    private func persist() {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if tab == nil {
            guard !draft.isEmpty || hasTitle else { return }
            let made = WrittenTab()
            modelContext.insert(made)
            tab = made
        }
        guard let tab else { return }
        tab.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        tab.write(WrittenTabPayload(content: draft.content, openMidi: tuning.openMidi, tuningLabel: tuning.label))
    }

    /// Closing: a tab this visit made and left empty isn't kept.
    private func finish() {
        guard let tab, madeHere, draft.isEmpty,
              title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        modelContext.delete(tab)
        self.tab = nil
    }
}
